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
use std::collections::BTreeSet;
use std::process::Command;

pub struct DbHandle {
    alpm: Alpm,
}

impl DbHandle {
    pub fn new() -> Result<Self, String> {
        let alpm =
            Alpm::new("/", "/var/lib/pacman").map_err(|e| format!("Failed to create alpm: {e}"))?;

        let repositories = Command::new("pacman-conf")
            .arg("--repo-list")
            .output()
            .ok()
            .filter(|output| output.status.success())
            .map(|output| {
                String::from_utf8_lossy(&output.stdout)
                    .lines()
                    .map(str::trim)
                    .filter(|name| !name.is_empty())
                    .map(str::to_owned)
                    .collect::<Vec<_>>()
            })
            .filter(|names| !names.is_empty())
            .unwrap_or_else(|| {
                ["core", "extra", "community", "multilib"]
                    .into_iter()
                    .map(str::to_owned)
                    .collect()
            });

        for name in repositories {
            alpm.register_syncdb(name.as_bytes(), alpm::SigLevel::NONE)
                .map_err(|e| format!("Failed to register {name}: {e}"))?;
        }

        Ok(Self { alpm })
    }

    /// Interrupt any in-progress transaction.
    pub fn interrupt(&mut self) {
        self.alpm.trans_interrupt().ok();
    }

    // ── Search ───────────────────────────────────────────────────────────────

    pub fn search_repo(&self, query: &str, repository: &str) -> (Vec<PackageInfo>, Vec<String>) {
        let query_lower = query.to_lowercase();
        let mut results: Vec<PackageInfo> = Vec::new();
        let mut categories = BTreeSet::new();
        let mut has_ungrouped = false;
        let local = self.alpm.localdb();

        for db in self.alpm.syncdbs().iter() {
            if !repository.is_empty() && db.name() != repository {
                continue;
            }
            for pkg in db.pkgs().iter() {
                for group in pkg.groups().iter() {
                    categories.insert(group.to_string());
                }
                has_ungrouped |= pkg.groups().is_empty();

                if query.is_empty() || pkg.name().to_lowercase().contains(&query_lower)
                    || pkg.version().to_lowercase().contains(&query_lower)
                    || pkg.desc().unwrap_or("").to_lowercase().contains(&query_lower)
                {
                    let mut info: PackageInfo = PkgFromAlpm(pkg).into();
                    info.installed = local.pkg(pkg.name().as_bytes()).is_ok();
                    results.push(info);
                }
            }
        }

        results.sort_by(|a, b| {
            a.name
                .cmp(&b.name)
                .then_with(|| a.repo.cmp(&b.repo))
                .then_with(|| a.version.cmp(&b.version))
        });
        if has_ungrouped {
            categories.insert("Uncategorized".to_string());
        }
        (results, categories.into_iter().collect())
    }

    pub fn repository_names(&self) -> Vec<String> {
        self.alpm
            .syncdbs()
            .iter()
            .map(|db| db.name().to_string())
            .collect()
    }

    pub fn is_installed(&self, name: &str) -> bool {
        self.alpm.localdb().pkg(name.as_bytes()).is_ok()
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
            .map(|pkg| {
                let mut info: PackageInfo = PkgFromAlpm(pkg).into();
                info.installed = true;
                info
            })
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
        // Repository databases are system-owned. Let pacman acquire its normal
        // lock and run through polkit instead of attempting a user-owned libalpm
        // update that fails with a database lock/permission error.
        let output = privileged_pacman(&["-Sy", "--noconfirm"])?;
        if output.status.success() {
            self.reload()?;
            Ok("Package databases refreshed".into())
        } else {
            Err(command_error("Database refresh failed", &output))
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
            .trans_init(alpm::TransFlag::NO_LOCK | alpm::TransFlag::CASCADE)
            .map_err(|e| e.to_string())?;

        for name in packages {
            let pkg = self
                .alpm
                .syncdbs()
                .iter()
                .find_map(|db| db.pkg(name.as_bytes()).ok())
                .ok_or_else(|| format!("Package '{name}' not found in repositories"));
            let pkg = match pkg {
                Ok(pkg) => pkg,
                Err(error) => { self.alpm.trans_release().ok(); return Err(error); }
            };

            if let Err(error) = self.alpm.trans_add_pkg(pkg) {
                let message = error.to_string();
                self.alpm.trans_release().ok();
                return Err(message);
            }
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
                .map_err(|_| format!("Package '{name}' is not installed"));
            let pkg = match pkg {
                Ok(pkg) => pkg,
                Err(error) => { self.alpm.trans_release().ok(); return Err(error); }
            };

            if let Err(error) = self.alpm.trans_remove_pkg(&pkg) {
                let message = error.to_string();
                self.alpm.trans_release().ok();
                return Err(message);
            }
            preview.remove.push(PkgFromAlpm(&pkg).into());
        }

        if self.alpm.trans_prepare().is_err() {
            self.alpm.trans_release().ok();
            return Err("Removal conflict".into());
        }

        let local = self.alpm.localdb();
        let removal_names: BTreeSet<String> = self.alpm.trans_remove().iter()
            .map(|pkg| pkg.name().to_string()).collect();
        let explicit_names: BTreeSet<&str> = packages.iter().map(String::as_str).collect();
        let remove: Vec<_> = self.alpm.trans_remove().iter()
            .filter(|pkg| explicit_names.contains(pkg.name()))
            .map(|pkg| PkgFromAlpm(pkg).into()).collect();
        let cascade: Vec<_> = self.alpm.trans_remove().iter()
            .filter(|pkg| !explicit_names.contains(pkg.name()))
            .map(|pkg| PkgFromAlpm(pkg).into()).collect();

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

        preview.remove = remove;
        preview.cascade = cascade;
        preview.required_by = required_by;
        self.alpm.trans_release().ok();
        Ok(())
    }

    /// Execute the staged transaction.
    pub fn commit(&mut self, preview: &super::transaction::Preview) -> Result<String, String> {
        if preview.system_upgrade {
            run_pacman(&["-Syu", "--noconfirm"])?;
        } else if !preview.install.is_empty() || !preview.reinstall.is_empty() {
            let packages: Vec<&str> = preview.install.iter().chain(&preview.reinstall)
                .filter(|pkg| pkg.source == "repo")
                .map(|pkg| pkg.name.as_str()).collect();
            if packages.is_empty() {
                return Err("AUR installation is not supported by this application".into());
            }
            let mut args = vec!["-S", "--needed", "--noconfirm", "--"];
            args.extend(packages);
            run_pacman(&args)?;
        } else if !preview.remove.is_empty() || !preview.cascade.is_empty() {
            let expected: BTreeSet<&str> = preview.all_removing().into_iter().map(|pkg| pkg.name.as_str()).collect();
            if expected.len() != preview.remove.len() + preview.cascade.len() {
                return Err("Reviewed removal contains duplicate package names".into());
            }
            let mut args = vec!["-R", "--noconfirm", "--"];
            args.extend(expected);
            run_pacman(&args)?;
        } else {
            return Err("The reviewed transaction contains no supported changes".into());
        }
        self.reload()?;
        Ok("Transaction completed successfully".into())
    }

    fn reload(&mut self) -> Result<(), String> {
        self.alpm = Self::new()?.alpm;
        Ok(())
    }
}

fn privileged_pacman(args: &[&str]) -> Result<std::process::Output, String> {
    Command::new("pkexec").arg("pacman").args(args).output()
        .or_else(|_| Command::new("sudo").arg("pacman").args(args).output())
        .map_err(|e| format!("Could not start privileged pacman: {e}"))
}

fn run_pacman(args: &[&str]) -> Result<(), String> {
    let output = privileged_pacman(args)?;
    if output.status.success() { Ok(()) } else { Err(command_error("Package transaction failed", &output)) }
}

fn command_error(label: &str, output: &std::process::Output) -> String {
    let detail = String::from_utf8_lossy(&output.stderr).trim().to_owned();
    if detail.is_empty() { format!("{label} (exit {})", output.status) }
    else { format!("{label}: {detail}") }
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
            installed: false,
            size: pkg.size() as u64,
            installed_at: pkg.install_date().unwrap_or(0),
            reason: Some(match pkg.reason() {
                PackageReason::Explicit => "explicit",
                PackageReason::Depend => "dependency",
            }
            .to_string()),
            groups: pkg.groups().iter().map(|group| group.to_string()).collect(),
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
            groups: Vec::new(),
            protected: false,
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
    #[serde(default)]
    pub groups: Vec<String>,
    #[serde(default)]
    pub protected: bool,
}
