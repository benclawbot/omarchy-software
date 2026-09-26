//! Transaction preview and cache management.

use crate::alpm_db::PackageInfo;
use serde::{Deserialize, Serialize};
use std::process::Command;
use std::time::Duration;

/// A staged transaction — the diff the user approves before Apply.
#[derive(Debug, Clone, Serialize, Deserialize, Default)]
pub struct Preview {
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

/// Run `paccache` to clean the package cache.
///
/// `mode`: "all" removes everything; "keep_last" keeps the most recent installed version.
pub fn clean_cache(mode: &str) -> Result<(u64, u32), String> {
    let cache_dir = std::path::Path::new("/var/cache/pacman/pkg");
    if !cache_dir.exists() {
        return Ok((0, 0));
    }

    let output = if mode == "all" {
        Command::new("paccache")
            .args(["-r", "-c", "/var/cache/pacman/pkg", "--all"])
            .output()
            .map_err(|e| format!("paccache failed: {e}"))?
    } else {
        // keep_last: keep 1 most recent version of each package
        Command::new("paccache")
            .args(["-r", "-c", "/var/cache/pacman/pkg", "-k", "1"])
            .output()
            .map_err(|e| format!("paccache failed: {e}"))?
    };

    let stderr = String::from_utf8_lossy(&output.stderr);

    // Parse "removed X packages (YMB)" from paccache output
    let mut freed_bytes: u64 = 0;
    let mut removed_count: u32 = 0;
    for line in stderr.lines() {
        if line.starts_with("removing") {
            // e.g. "removing firefox-139.0-1 (50.4 MiB)..."
            if let Some(paren) = line.find('(') {
                let size_str = &line[paren + 1..];
                if let Some(end) = size_str.find(')') {
                    let size_part = &size_str[..end];
                    freed_bytes += parse_size(size_part);
                    removed_count += 1;
                }
            }
        }
    }

    Ok((freed_bytes, removed_count))
}

fn parse_size(s: &str) -> u64 {
    let s = s.trim();
    let num: f64 = s.split_whitespace().next()
        .and_then(|n| n.parse::<f64>().ok())
        .unwrap_or(0.0);
    let mb = if s.contains("GiB") { 1024.0 * 1024.0 * 1024.0 }
        else if s.contains("MiB") { 1024.0 * 1024.0 }
        else if s.contains("KiB") { 1024.0 }
        else { 1.0 };
    (num * mb) as u64
}
