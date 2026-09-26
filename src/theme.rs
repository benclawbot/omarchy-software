//! Theme adapter — reads the active Omarchy palette and exposes it to the QML layer.

use serde::{Deserialize, Serialize};
use tracing::info;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct Theme {
    pub mode: String,
    pub accent: String,
    pub selection: String,
    pub muted: String,
    pub background: String,
    pub dark_background: String,
    pub darker_background: String,
    pub lighter_background: String,
    pub foreground: String,
    pub dark_foreground: String,
    pub light_foreground: String,
    pub bright_foreground: String,
    pub red: String,
    pub yellow: String,
    pub orange: String,
    pub green: String,
    pub cyan: String,
    pub blue: String,
    pub magenta: String,
    pub brown: String,
}

impl Default for Theme {
    fn default() -> Self {
        // Catppuccin Mocha dark — Omarchy default
        Self {
            mode: "dark".into(),
            accent: "#89b4fa".into(),
            selection: "#353543".into(),
            muted: "#45475a".into(),
            background: "#1e1e2e".into(),
            dark_background: "#171723".into(),
            darker_background: "#0f0f17".into(),
            lighter_background: "#353543".into(),
            foreground: "#cdd6f4".into(),
            dark_foreground: "#9aa1b7".into(),
            light_foreground: "#d5dcf6".into(),
            bright_foreground: "#dae0f7".into(),
            red: "#f38ba8".into(),
            yellow: "#f9e2af".into(),
            orange: "#f59cb5".into(),
            green: "#a6e3a1".into(),
            cyan: "#94e2d5".into(),
            blue: "#89b4fa".into(),
            magenta: "#cba6f7".into(),
            brown: "#935e6d".into(),
        }
    }
}

impl Theme {
    /// Load from `~/.local/state/omarchy/current/theme/colors.toml`.
    /// Falls back to defaults if the file is absent or malformed.
    pub fn load() -> Self {
        let path = omarchy_state_dir()
            .map(|p| p.join("theme").join("colors.toml"));

        let Some(path) = path else {
            info!("No Omarchy state dir; using default theme");
            return Self::default();
        };

        if !path.exists() {
            info!("Omarchy theme file not found; using default");
            return Self::default();
        }

        match std::fs::read_to_string(&path) {
            Ok(content) => Self::parse_toml(&content).unwrap_or_else(|e| {
                tracing::warn!("Failed to parse Omarchy theme: {e}; using default");
                Self::default()
            }),
            Err(e) => {
                tracing::warn!("Failed to read Omarchy theme: {e}; using default");
                Self::default()
            }
        }
    }

    fn parse_toml(content: &str) -> Result<Self, toml::de::Error> {
        #[derive(Deserialize)]
        struct Raw {
            mode: Option<String>,
            accent: Option<String>,
            selection: Option<String>,
            muted: Option<String>,
            background: Option<String>,
            dark_background: Option<String>,
            darker_background: Option<String>,
            lighter_background: Option<String>,
            foreground: Option<String>,
            dark_foreground: Option<String>,
            light_foreground: Option<String>,
            bright_foreground: Option<String>,
            red: Option<String>,
            yellow: Option<String>,
            orange: Option<String>,
            green: Option<String>,
            cyan: Option<String>,
            blue: Option<String>,
            magenta: Option<String>,
            brown: Option<String>,
        }

        let raw: Raw = toml::from_str(content)?;

        Ok(Self {
            mode: raw.mode.unwrap_or_else(|| "dark".into()),
            accent: raw.accent.unwrap_or_else(|| "#89b4fa".into()),
            selection: raw.selection.unwrap_or_else(|| "#353543".into()),
            muted: raw.muted.unwrap_or_else(|| "#45475a".into()),
            background: raw.background.unwrap_or_else(|| "#1e1e2e".into()),
            dark_background: raw.dark_background.unwrap_or_else(|| "#171723".into()),
            darker_background: raw.darker_background.unwrap_or_else(|| "#0f0f17".into()),
            lighter_background: raw.lighter_background.unwrap_or_else(|| "#353543".into()),
            foreground: raw.foreground.unwrap_or_else(|| "#cdd6f4".into()),
            dark_foreground: raw.dark_foreground.unwrap_or_else(|| "#9aa1b7".into()),
            light_foreground: raw.light_foreground.unwrap_or_else(|| "#d5dcf6".into()),
            bright_foreground: raw.bright_foreground.unwrap_or_else(|| "#dae0f7".into()),
            red: raw.red.unwrap_or_else(|| "#f38ba8".into()),
            yellow: raw.yellow.unwrap_or_else(|| "#f9e2af".into()),
            orange: raw.orange.unwrap_or_else(|| "#f59cb5".into()),
            green: raw.green.unwrap_or_else(|| "#a6e3a1".into()),
            cyan: raw.cyan.unwrap_or_else(|| "#94e2d5".into()),
            blue: raw.blue.unwrap_or_else(|| "#89b4fa".into()),
            magenta: raw.magenta.unwrap_or_else(|| "#cba6f7".into()),
            brown: raw.brown.unwrap_or_else(|| "#935e6d".into()),
        })
    }
}

fn omarchy_state_dir() -> Option<std::path::PathBuf> {
    std::env::var("XDG_STATE_HOME")
        .map(std::path::PathBuf::from)
        .ok()
        .or_else(|| {
            std::env::var("HOME")
                .map(|h| std::path::PathBuf::from(h).join(".local").join("state"))
                .ok()
        })
        .map(|p| p.join("omarchy"))
}

pub fn init_logging() -> Result<(), String> {
    use tracing_subscriber::{fmt, prelude::*, EnvFilter};

    let state_dir = omarchy_state_dir()
        .ok_or("Cannot find XDG_STATE_HOME or HOME")?;
    let log_dir = state_dir.join("logs");
    std::fs::create_dir_all(&log_dir)
        .map_err(|e| format!("Cannot create log dir: {e}"))?;

    let file_appender = tracing_appender::rolling::daily(&log_dir, "omarchy-software.log");
    let (non_blocking, _guard) = tracing_appender::non_blocking(file_appender);

    // Leak the guard so logging lives for the duration of the process
    std::mem::forget(_guard);

    tracing_subscriber::registry()
        .with(EnvFilter::from_default_env().add_directive(tracing::Level::INFO.into()))
        .with(fmt::layer().with_writer(non_blocking))
        .init();

    Ok(())
}
