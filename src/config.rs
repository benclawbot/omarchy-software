//! Configuration — XDG-compliant, versioned, atomic writes.

use serde::{Deserialize, Serialize};
use std::path::PathBuf;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Config {
    pub refresh_interval_secs: u32,
    pub show_system_packages: bool,
    pub aur_enabled: bool,
    pub ignored_packages: Vec<String>,
    pub ignored_groups: Vec<String>,
    pub cache_keep: u32, // number of cached versions to keep per package
    pub protected_packages: Vec<String>,
}

impl Default for Config {
    fn default() -> Self {
        Self {
            refresh_interval_secs: 60,
            show_system_packages: false,
            aur_enabled: true,
            ignored_packages: vec![],
            ignored_groups: vec![],
            cache_keep: 3,
            protected_packages: PROTECTED_LIST.iter().map(|s| s.to_string()).collect(),
        }
    }
}

impl Config {
    pub fn load() -> Self {
        let path = config_path();
        if !path.exists() {
            return Self::default();
        }
        std::fs::read_to_string(&path)
            .ok()
            .and_then(|c| toml::from_str(&c).ok())
            .unwrap_or_default()
    }

    pub fn save(&self) -> Result<(), String> {
        let path = config_path();
        if let Some(parent) = path.parent() {
            std::fs::create_dir_all(parent)
                .map_err(|e| format!("Cannot create config dir: {e}"))?;
        }
        let content = toml::to_string_pretty(self)
            .map_err(|e| format!("Cannot serialise config: {e}"))?;
        atomic_write(&path, content)
    }
}

fn config_path() -> PathBuf {
    std::env::var("XDG_CONFIG_HOME")
        .map(PathBuf::from)
        .unwrap_or_else(|_| {
            PathBuf::from(std::env::var("HOME").unwrap_or_default()).join(".config")
        })
        .join("omarchy-software")
        .join("config.toml")
}

fn atomic_write(path: &PathBuf, content: String) -> Result<(), String> {
    let tmp = path.with_extension("tmp");
    std::fs::write(&tmp, &content)
        .map_err(|e| format!("Cannot write config: {e}"))?;
    std::fs::rename(&tmp, path)
        .map_err(|e| format!("Cannot atomically move config: {e}"))?;
    Ok(())
}

// Packages that the GUI will never offer to remove.
const PROTECTED_LIST: &[&str] = &[
    "pacman",
    "systemd",
    "linux",
    "linux-lts",
    "mkinitcpio",
    "sudo",
    "base",
    "base-devel",
    "glibc",
    "gcc",
    "coreutils",
    "shadow", // needed for passwd/su
    "openssh", // sshd may be needed
    "NetworkManager",
    "dbus",
    "dbus-broker",
    "gawk",
    "grep",
    "sed",
    "tar",
    " gzip",
    "pacman-mirrors", // CachyOS
];
