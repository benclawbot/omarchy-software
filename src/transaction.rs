//! Transaction preview and cache management.

use crate::alpm_db::PackageInfo;
use serde::{Deserialize, Serialize};

/// A staged transaction — the diff the user approves before Apply.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Preview {
    #[serde(default)]
    pub system_upgrade: bool,
    #[serde(default)]
    pub install: Vec<PackageInfo>,
    #[serde(default)]
    pub reinstall: Vec<PackageInfo>,
    #[serde(default)]
    pub remove: Vec<PackageInfo>,
    #[serde(default)]
    pub cascade: Vec<PackageInfo>, // required-by cascade
    #[serde(default)]
    pub required_by: std::collections::HashMap<String, Vec<String>>, // pkg → packages that need it
}

impl Preview {
    pub fn new() -> Self {
        Self::default()
    }

    pub fn add_install_repo(&mut self, pkg: &PackageInfo) {
        if !self.install.iter().any(|p| p.name == pkg.name) {
            self.install.push(pkg.clone());
        }
    }

    pub fn add_install_aur(&mut self, pkg: &PackageInfo) {
        if !self.install.iter().any(|p| p.name == pkg.name) {
            self.install.push(pkg.clone());
        }
    }

    pub fn total_count(&self) -> usize {
        self.install.len() + self.reinstall.len() + self.remove.len() + self.cascade.len()
    }

    /// Returns all packages that would be removed (explicit + cascade).
    pub fn all_removing(&self) -> Vec<&PackageInfo> {
        self.remove.iter().chain(self.cascade.iter()).collect()
    }
}
