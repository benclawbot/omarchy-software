//! libalpm database access layer.
//! Wraps the alpm crate to expose structured package queries and transaction previews.

use alpm::{Alpm, Db, Package, SyncDB};
use serde::{Deserialize, Serialize};
use std::collections::HashSet;

pub struct DbHandle {
    alpm: Alpm,
}

impl DbHandle {
    pub fn new() -> Result<Self, String> {
        let root = std::path::Path::new("/");
        let db_path = std::path::Path::new("/var/lib/pacman");
        let cache_path = std::env::var("XDG_CACHE_HOME")
            .map(std::path::PathBuf::from)
            .unwrap_or_else(|_| {
                std::path::PathBuf::from(std::env::var("HOME").unwrap_or_default())
                    .join(".cache")
            })
            .join("omarchy-software");

        std::fs::create_dir_all(&cache_path)
            .map_err(|e| format!("Cannot create cache dir: {e}"))?;

        let alpm = Alpm::new(root, db_path)
            .map_err(|e| format!("Failed to create alpm: {e}"))?;

        alpm.register_syncdbs(&["core", "extra", "community", "multilib"])
            .map_err(|e| format!("Failed to register syncdbs: {e}"))?;

        Ok(Self { alpm })
    }

    pub fn db(&self) -> SyncDB<'_> {
        self.alpm.syncdbs()
    }

    pub fn search_repo(&self, query: &str) -> Vec<PackageInfo> {
        let query_lower = query.to_lowercase();
        let mut results = Vec::new();

        for db in self.db().iter() {
            for pkg in db.search(query_lower.split_whitespace()) {
                results.push(PkgFromAlpm(&pkg).into());
            }
        }

        results.sort_by(|a, b| a.name.cmp(&b.name));
        results.dedup_by(|a, b| a.name == b.name);
        results
    }

    pub fn installed_packages(&self, filter: &str, sort: &str, reverse: bool) -> Vec<PackageInfo> {
        let pkgs: Vec<_> = self.alpm.localdb().pkgcache().iter().collect();

        let mut packages: Vec<PackageInfo> = pkgs
            .into_iter()
            .filter(|pkg| {
                if filter == "explicit" {
                    pkg.reason() == alpm::PackageReason::Explicit
                } else if filter == "dependency" {
                    pkg.reason() == alpm::PackageReason::Dependency
                } else if filter == "orphan" {
                    // An orphan has no package depending on it
                    pkg.reason() == alpm::PackageReason::Dependency
                        && self.alpm.localdb().pkgcache()
                            .iter()
                            .all(|other| {
                                other.name() == pkg.name()
                                    || !other.depends().iter().any(|d| d.name() == pkg.name())
                            })
                } else {
                    true
                }
            })
            .map(|pkg| PkgFromAlpm(pkg).into())
            .collect();

        match sort {
            "size" => packages.sort_by(|a, b| a.size.cmp(&b.size)),
            "date" => packages.sort_by(|a, b| b.installed_at.cmp(&a.installed_at)),
            _ => packages.sort_by(|a, b| a.name.cmp(&b.name)),
        }

        if reverse {
            packages.reverse();
        }

        packages
    }

    pub fn check_updates(&self) -> (Vec<PackageInfo>, Vec<PackageInfo>) {
        let mut repos = Vec::new();
        let mut aur = Vec::new();

        self.alpm.syncdbs_mut()
            .iter_mut()
            .for_each(|db| {
                if let Ok(_) = db.update(false) {
                    for pkg in db.pkgcache().iter() {
                        if let Some(local) = self.alpm.localdb().pkg(pkg.name()) {
                            if local.version() != pkg.version() {
                                repos.push(PkgFromAlpm(pkg));
                            }
                        } else {
                            repos.push(PkgFromAlpm(pkg));
                        }
                    }
                }
            });

        (repos, aur)
    }

    pub fn refresh(&self) -> Result<String, String> {
        self.alpm.syncdbs_mut()
            .iter_mut()
            .try_fold(String::new(), |mut acc, db| {
                db.update(true).map_err(|e| e.to_string())?;
                acc.push_str(&format!("{} refreshed, ", db.name()));
                Ok(acc)
            })
            .map(|s| if s.is_empty() { "Already up to date".to_string() } else { s })
            .map_err(|e| e)
    }

    pub fn preview_install(
        &self,
        packages: &[String],
        preview: &mut super::transaction::Preview,
    ) -> Result<(), String> {
        let mut trans = self.alpm.trans_init(alpm::TransactionFlag::NO_LOCKS)
            .map_err(|e| e.to_string())?;

        for name in packages {
            let db = self.db();
            match db.pkg(name) {
                Some(pkg) => {
                    trans.add_pkg(&pkg).map_err(|e| e.to_string())?;
                    preview.add_install_repo(&PkgFromAlpm(&pkg));
                }
                None => {
                    trans.trans_release().ok();
                    return Err(format!("Package '{name}' not found in repositories"));
                }
            }
        }

        match trans.prepare() {
            Ok(_) => {
                let to_install: Vec<_> = trans.to_add()
                    .iter()
                    .map(|p| PkgFromAlpm(p).into())
                    .collect();
                let to_reinstall: Vec<_> = trans.to_reinstall()
                    .iter()
                    .map(|p| PkgFromAlpm(p).into())
                    .collect();

                preview.install.extend(to_install);
                preview.reinstall.extend(to_reinstall);
                trans.trans_release().ok();
                Ok(())
            }
            Err(e) => {
                trans.trans_release().ok();
                Err(format!("Dependency conflict: {e}"))
            }
        }
    }

    pub fn preview_remove(
        &self,
        packages: &[String],
        preview: &mut super::transaction::Preview,
    ) -> Result<(), String> {
        let mut trans = self.alpm.trans_init(alpm::TransactionFlag::NO_LOCKS)
            .map_err(|e| e.to_string())?;

        for name in packages {
            if let Some(pkg) = self.alpm.localdb().pkg(name) {
                trans.remove_pkg(&pkg).map_err(|e| e.to_string())?;
                preview.remove.push(PkgFromAlpm(&pkg));
            } else {
                trans.trans_release().ok();
                return Err(format!("Package '{name}' is not installed"));
            }
        }

        match trans.prepare() {
            Ok(_) => {
                let cascade: Vec<_> = trans.to_remove()
                    .iter()
                    .filter(|p| !packages.contains(&p.name().to_string()))
                    .map(|p| PkgFromAlpm(p).into())
                    .collect();

                // Required-by information
                let mut required_by: std::collections::HashMap<String, Vec<String>> = std::collections::HashMap::new();
                for pkg in trans.to_remove() {
                    let deps: Vec<_> = self.alpm.localdb().pkgcache()
                        .iter()
                        .filter(|p| {
                            p.depends().iter().any(|d| d.name() == pkg.name())
                        })
                        .map(|p| p.name().to_string())
                        .collect();
                    if !deps.is_empty() {
                        required_by.insert(pkg.name().to_string(), deps);
                    }
                }

                preview.cascade.extend(cascade);
                preview.required_by = required_by;

                trans.trans_release().ok();
                Ok(())
            }
            Err(e) => {
                trans.trans_release().ok();
                Err(format!("Removal conflict: {e}"))
            }
        }
    }

    pub fn commit(&self, preview: &super::transaction::Preview) -> Result<String, String> {
        let mut trans = self.alpm.trans_init(alpm::TransactionFlag::NO_LOCKS)
            .map_err(|e| e.to_string())?;

        // Add packages to install
        for pkg_info in preview.install.iter().chain(preview.reinstall.iter()) {
            if let Some(pkg) = self.db().pkg(&pkg_info.name) {
                trans.add_pkg(&pkg).map_err(|e| e.to_string())?;
            }
        }

        // Add packages to remove
        for pkg_info in &preview.remove {
            if let Some(pkg) = self.alpm.localdb().pkg(&pkg_info.name) {
                trans.remove_pkg(&pkg).map_err(|e| e.to_string())?;
            }
        }

        trans.prepare().map_err(|e| e.to_string())?;
        trans.commit().map_err(|e| e.to_string())?;

        Ok("Transaction completed successfully".to_string())
    }
}

impl From<DbHandle> for super::Db {
    fn from(_: DbHandle) -> Self {
        // Db wraps the handle; we use Arc<Mutex<DbHandle>> in main.rs
        // This type alias exists so the main module can use it generically
        unimplemented!()
    }
}

// ── Conversions ─────────────────────────────────────────────────────────────

struct PkgFromAlpm<'a>(&'a Package<'a>);

impl<'a> From<PkgFromAlpm<'a>> for PackageInfo {
    fn from(p: PkgFromAlpm<'a>) -> Self {
        let pkg = p.0;
        Self {
            name: pkg.name().to_string(),
            version: pkg.version().to_string(),
            description: pkg.description().to_string(),
            source: "repo".to_string(),
            repo: pkg.db().map(|d| d.name().to_string()).unwrap_or_default(),
            installed: true,
            size: pkg.size() as u64,
            installed_at: pkg.installdate(),
            reason: Some(match pkg.reason() {
                alpm::PackageReason::Explicit => "explicit",
                alpm::PackageReason::Dependency => "dependency",
            }.to_string()),
            ..Default::default()
        }
    }
}

// ── Types ───────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct PackageInfo {
    pub name: String,
    pub version: String,
    pub description: String,
    #[serde(default)]
    pub source: String, // "repo" | "aur"
    #[serde(default)]
    pub repo: String,
    #[serde(default)]
    pub installed: bool,
    #[serde(default)]
    pub size: u64,
    #[serde(default)]
    pub installed_at: i64,
    #[serde(default)]
    pub reason: Option<String>,
    #[serde(default)]
    pub votes: Option<i32>,
    #[serde(default)]
    pub aur_version: Option<String>, // latest AUR version if different from installed
    #[serde(default)]
    pub out_of_date: Option<bool>,
}
