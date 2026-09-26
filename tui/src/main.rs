//! omarchy-software-tui
//! Terminal launcher / quick stats panel for omarchy-software.

use cursive::theme::{BaseColor, Color, PaletteColor, Theme};
use cursive::views::{Dialog, LinearLayout, SelectView, TextView};
use cursive::Cursive;
use cursive::CursiveExt;
use std::process::Command;

const BINARY_PATHS: &[&str] = &[
    "/usr/lib/omarchy-software/omarchy-software-core",
    "/usr/local/lib/omarchy-software/omarchy-software-core",
    "./build/omarchy-software-core",
    "./target/release/omarchy-software-core",
];

fn installed_count() -> usize {
    AlpmHandle::new()
        .map(|h| h.count_installed())
        .unwrap_or(0)
}

struct AlpmHandle {
    alpm: alpm::Alpm,
}

impl AlpmHandle {
    fn new() -> Result<Self, String> {
        let alpm =
            alpm::Alpm::new("/", "/var/lib/pacman").map_err(|e| e.to_string())?;
        Ok(Self { alpm })
    }

    fn count_installed(&self) -> usize {
        self.alpm.localdb().pkgs().iter().count()
    }
}

fn find_core_binary() -> Option<String> {
    BINARY_PATHS.iter().find_map(|p| {
        std::path::Path::new(p).exists().then(|| (*p).to_string())
    })
}

fn launch_gui(s: &mut Cursive) {
    match find_core_binary() {
        Some(path) => {
            match Command::new(&path).spawn() {
                Ok(_) => {
                    s.add_layer(
                        Dialog::text("GUI launched!")
                            .title("omarchy-software")
                            .button("OK", |s| s.quit()),
                    );
                }
                Err(e) => {
                    s.add_layer(
                        Dialog::text(format!("Failed to launch:\n{e}"))
                            .title("Error")
                            .button("OK", |_| {}),
                    );
                }
            }
        }
        None => {
            s.add_layer(Dialog::text(format!(
                "omarchy-software-core not found.\n\nSearched:\n{}",
                BINARY_PATHS.join("\n")
            )).title("Binary not found").button("OK", |s| { s.pop_layer(); }));
        }
    }
}

fn refresh_databases(s: &mut Cursive) {
    let output = Command::new("pkexec")
        .args(["pacman", "-Sy", "--noconfirm"])
        .output();

    match output {
        Ok(out) => {
            if out.status.success() {
                let stdout = String::from_utf8_lossy(&out.stdout);
                let count = stdout.lines().filter(|l| l.contains("::")).count();
                s.add_layer(Dialog::text(format!(
                    "Databases refreshed.\n{count} repo(s) updated."
                )).title("Done").button("OK", |s| { s.pop_layer(); }));
            } else {
                let stderr = String::from_utf8_lossy(&out.stderr);
                s.add_layer(Dialog::text(format!("Refresh failed:\n{stderr}"))
                    .title("Error")
                    .button("OK", |s| { s.pop_layer(); }));
            }
        }
        Err(e) => {
            s.add_layer(Dialog::text(format!("Could not run pkexec:\n{e}"))
                .title("Error")
                .button("OK", |s| { s.pop_layer(); }));
        }
    }
}

fn main() {
    let mut siv = Cursive::new();

    // Catppuccin Mocha dark — matches omarchy-software glass aesthetic
    let mut theme = Theme::default();
    theme.palette[PaletteColor::Background] = Color::Dark(BaseColor::Blue);
    theme.palette[PaletteColor::Shadow] = Color::Dark(BaseColor::Black);
    theme.palette[PaletteColor::View] = Color::Dark(BaseColor::Blue);
    theme.palette[PaletteColor::Primary] = Color::Light(BaseColor::Blue);    // #89b4fa
    theme.palette[PaletteColor::Secondary] = Color::Light(BaseColor::Magenta); // #cba6f7
    theme.palette[PaletteColor::Tertiary] = Color::Light(BaseColor::Cyan); // #94e2d5
    theme.palette[PaletteColor::Highlight] = Color::Light(BaseColor::Yellow); // #f9e2af
    theme.shadow = false;
    siv.set_theme(theme);

    let count = installed_count();

    // Simple text-based menu using a SelectView
    let mut menu = SelectView::new();
    menu.add_item("Launch GUI", "launch");
    menu.add_item("Refresh databases", "refresh");
    menu.add_item("Quit", "quit");
    menu.set_on_submit(|s, selected: &str| {
        s.pop_layer();
        match selected {
            "launch" => launch_gui(s),
            "refresh" => refresh_databases(s),
            "quit" => s.quit(),
            _ => {}
        }
    });

    let content = LinearLayout::vertical()
        .child(TextView::new("omarchy-software")
            .style(cursive::theme::ColorStyle::new(
                Color::Light(BaseColor::Blue),
                Color::Dark(BaseColor::Black),
            )))
        .child(TextView::new(format!("Installed packages: {count}"))
            .style(cursive::theme::ColorStyle::new(
                Color::Light(BaseColor::Cyan),
                Color::Dark(BaseColor::Black),
            )))
        .child(TextView::new(""))
        .child(menu);

    siv.add_layer(
        Dialog::new()
            .title("omarchy-software")
            .content(content)
            .button("Quit", |s| s.quit()),
    );

    siv.run();
}
