//! libalpm database access layer — alpm v5 API.
//!
//! Key alpm v5 patterns:
//!   - syncdbs() → AlpmList<&Db>  (read-only)
//!   - syncdbs_mut() → AlpmList<DbMut>  (for update())
//!   - db.pkgs() → AlpmList<&Package>  (not pkgcache)
//!   - db.pkg(name.as_bytes()) → Result<&Package>
//!   - Transaction state lives on the Alpm handle; all trans_* methods are on Alpm

use alpm::{Alpm, Package, PackageReason};
use serde::{Deserialize, Serialize};

pub struct DbHandle {
    alpm: Alpm,
}

impl DbHandle {
    pub fn new() -> Result<Self, String> {
        let alpm =
            Alpm::new("/", "/var/lib/pacman").map_err(|e| format!("Failed to create alpm: {e}"))?;

        for name in ["core", "extra", "community", "multilib"] {
            alpm.register_syncdb(name, alpm::SigLevel::NONE)
                .map_err(|e| format!("Failed to register {name}: {e}"))?;
        }

        Ok(Self { alpm })
    }

    /// Interrupt any in-progress transaction.
    pub fn interrupt(&mut self) {
        self.alpm.trans_interrupt().ok();
    }

    // ── Search ───────────────────────────────────────────────────────────────

    pub fn search_repo(&self, query: &str) -> Vec<PackageInfo> {
        let query_lower = query.to_lowercase();
        let mut results: Vec<PackageInfo> = Vec::new();

        for db in self.alpm.syncdbs().iter() {
            for pkg in db.pkgs().iter() {
                if pkg.name().to_lowercase().contains(&query_lower)
                    || pkg.desc().unwrap_or("").to_lowercase().contains(&query_lower)
                {
                    results.push(PkgFromAlpm(pkg).into());
                }
            }
        }

        results.sort_by(|a, b| a.name.cmp(&b.name));
        results
    }

    // ── Installed packages ────────────────────────────────────────────────────

    pub fn installed_packages(&self, filter: &str, sort: &str, reverse: bool) -> Vec<PackageInfo> {
        let local = self.alpm.localdb();

        let mut packages: Vec<PackageInfo> = local
            .pkgs()
            .iter()
            .filter(|pkg| {
                let reason = pkg.reason();
                match filter {
                    "explicit" => reason == PackageReason::Explicit,
                    "dependency" => reason == PackageReason::Depend,
                    "orphan" => {
                        reason == PackageReason::Depend
                            && !local.pkgs().iter().any(|other| {
                                other.name() != pkg.name()
                                    && other.depends().iter().any(|d| d.name() == pkg.name())
                            })
                    }
                    _ => true,
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

    // ── Check updates ────────────────────────────────────────────────────────

    pub fn check_updates(&self) -> (Vec<PackageInfo>, Vec<PackageInfo>) {
        let mut repos = Vec::new();

        for db in self.alpm.syncdbs().iter() {
            for pkg in db.pkgs().iter() {
                if let Ok(local) = self.alpm.localdb().pkg(pkg.name().as_bytes()) {
                    if local.version() != pkg.version() {
                        repos.push(PkgFromAlpm(pkg).into());
                    }
                }
            }
        }

        (repos, Vec::new())
    }

    // ── Refresh databases ────────────────────────────────────────────────────

    pub fn refresh(&mut self) -> Result<String, String> {
        // alpm v5: update is on AlpmList<DbMut>, not on individual DbMut
        let syncdbs = self.alpm.syncdbs_mut();
        match syncdbs.update(true) {
            Ok(_) => {
                let names: Vec<String> = self.alpm.syncdbs().iter().map(|d| d.name().to_string()).collect();
                if names.is_empty() {
                    Ok("Already up to date".into())
                } else {
                    Ok(names.join(", ") + " refreshed")
                }
            }
            Err(e) => Err(format!("Refresh failed: {e}")),
        }
    }

    // ── Transaction ─────────────────────────────────────────────────────────

    /// Stage install of repo packages, prepare, and return what would be installed.
    pub fn preview_install(
        &mut self,
        packages: &[String],
        preview: &mut super::transaction::Preview,
    ) -> Result<(), String> {
        self.alpm
            .trans_init(alpm::TransFlag::NO_LOCK)
            .map_err(|e| e.to_string())?;

        for name in packages {
            let pkg = self
                .alpm
                .syncdbs()
                .iter()
                .find_map(|db| db.pkg(name.as_bytes()).ok())
                .ok_or_else(|| format!("Package '{name}' not found in repositories"))?;

            self.alpm
                .trans_add_pkg(pkg)
                .map_err(|e| e.to_string())?;
            preview.add_install_repo(&PkgFromAlpm(pkg).into());
        }

        if self.alpm.trans_prepare().is_err() {
            self.alpm.trans_release().ok();
            return Err("Dependency conflict".into());
        }

        let to_add: Vec<_> = self
            .alpm
            .trans_add()
            .iter()
            .map(|p| PkgFromAlpm(p).into())
            .collect();
        preview.install.extend(to_add);
        self.alpm.trans_release().ok();
        Ok(())
    }

    /// Stage remove, prepare, and return what would be removed including cascade.
    pub fn preview_remove(
        &mut self,
        packages: &[String],
        preview: &mut super::transaction::Preview,
    ) -> Result<(), String> {
        self.alpm
            .trans_init(alpm::TransFlag::NO_LOCK)
            .map_err(|e| e.to_string())?;

        for name in packages {
            let pkg = self
                .alpm
                .localdb()
                .pkg(name.as_bytes())
                .map_err(|_| format!("Package '{name}' is not installed"))?;

            self.alpm
                .trans_remove_pkg(&pkg)
                .map_err(|e| e.to_string())?;
            preview.remove.push(PkgFromAlpm(&pkg).into());
        }

        if self.alpm.trans_prepare().is_err() {
            self.alpm.trans_release().ok();
            return Err("Removal conflict".into());
        }

        let local = self.alpm.localdb();
        let cascade: Vec<_> = self
            .alpm
            .trans_remove()
            .iter()
            .filter(|p| !packages.contains(&p.name().to_string()))
            .map(|p| PkgFromAlpm(p).into())
            .collect();

        let mut required_by = std::collections::HashMap::new();
        for pkg in self.alpm.trans_remove().iter() {
            let deps: Vec<String> = local
                .pkgs()
                .iter()
                .filter(|other| {
                    other.name() != pkg.name()
                        && other.depends().iter().any(|d| d.name() == pkg.name())
                })
                .map(|p| p.name().to_string())
                .collect();
            if !deps.is_empty() {
                required_by.insert(pkg.name().to_string(), deps);
            }
        }

        preview.cascade.extend(cascade);
        preview.required_by = required_by;
        self.alpm.trans_release().ok();
        Ok(())
    }

    /// Execute the staged transaction.
    pub fn commit(&mut self, preview: &super::transaction::Preview) -> Result<String, String> {
        self.alpm
            .trans_init(alpm::TransFlag::NO_LOCK)
            .map_err(|e| e.to_string())?;

        for pkg_info in preview.install.iter().chain(preview.reinstall.iter()) {
            if let Some(pkg) = self
                .alpm
                .syncdbs()
                .iter()
                .find_map(|db| db.pkg(pkg_info.name.as_bytes()).ok())
            {
                self.alpm.trans_add_pkg(pkg).map_err(|e| e.to_string())?;
            }
        }

        for pkg_info in &preview.remove {
            if let Ok(pkg) = self.alpm.localdb().pkg(pkg_info.name.as_bytes()) {
                self.alpm.trans_remove_pkg(&pkg).map_err(|e| e.to_string())?;
            }
        }

        self.alpm.trans_prepare().map_err(|e| format!("Prepare error: {e}"))?;
        self.alpm.trans_commit().map_err(|e| format!("Commit error: {e}"))?;
        self.alpm.trans_release().ok();

        Ok("Transaction completed successfully".into())
    }
}

// ── Conversions ─────────────────────────────────────────────────────────────

struct PkgFromAlpm<'a>(&'a Package);

impl<'a> From<PkgFromAlpm<'a>> for PackageInfo {
    fn from(p: PkgFromAlpm<'a>) -> Self {
        let pkg = p.0;
        Self {
            name: pkg.name().to_string(),
            version: pkg.version().to_string(),
            description: pkg.desc().unwrap_or("").to_string(),
            source: "repo".to_string(),
            repo: pkg.db().map(|d| d.name().to_string()).unwrap_or_default(),
            installed: true,
            size: pkg.size() as u64,
            installed_at: pkg.install_date().unwrap_or(0),
            reason: Some(match pkg.reason() {
                PackageReason::Explicit => "explicit",
                PackageReason::Depend => "dependency",
            }
            .to_string()),
            ..Default::default()
        }
    }
}

impl Default for PackageInfo {
    fn default() -> Self {
        Self {
            name: String::new(),
            version: String::new(),
            description: String::new(),
            source: "repo".to_string(),
            repo: String::new(),
            installed: false,
            size: 0,
            installed_at: 0,
            reason: None,
            votes: None,
            aur_version: None,
            out_of_date: None,
        }
    }
}

// ── Types ───────────────────────────────────────────────────────────────────

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PackageInfo {
    pub name: String,
    pub version: String,
    pub description: String,
    #[serde(default)]
    pub source: String,
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
    pub aur_version: Option<String>,
    #[serde(default)]
    pub out_of_date: Option<bool>,
}
