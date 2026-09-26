# omarchy-software

A native GUI package manager for [Omarchy](https://github.com/omarchy/omarchy). Built with a Rust package worker and a Qt6 Quick/QML interface.

<p align="center">
  <img src="https://img.shields.io/badge/Rust-1.98.1-orange" />
  <img src="https://img.shields.io/badge/Qt-6.4+-purple" />
  <img src="https://img.shields.io/badge/License-MIT-blue" />
</p>

---

## Features

### Package Management
- **Repo packages** — directly via `libalpm` (no CLI wrapping), with warm in-memory cache
- **AUR packages** — searched and info-fetched via the AUR HTTP RPC (`aur` v0.2 crate)
- **Multi-select operations** — select several installed packages, then review their removal before applying
- **Change preview before Apply** — cascade removals and Required-By dependencies are surfaced with per-item controls before committing
- **Protected packages** — pacman, glibc, systemd, kernel, base and other critical packages are GUI-protected from removal

### Views
| Tab | Description |
|-----|-------------|
| **Remove** | Opens by default with every installed package; filter by explicit/dependency/orphan; select packages for reviewed removal |
| **Install** | Browse enabled repository packages; filter by repository and package group; search names, descriptions, and versions across repositories and AUR. Double-click repository packages to review installation; AUR results are informational only. |
| **Updates** | Refresh repository databases through polkit, review available system updates, then apply them with confirmation |

### UX
- **Source badges** — every package card shows a colour-coded pill:
  - <span style="color:#89b4fa">●</span> Blue — official repo
  - <span style="color:#cba6f7">●</span> Magenta — AUR
  - <span style="color:#94e2d5">●</span> Cyan — CachyOS repo
- **Floating panel aesthetic** — translucent surfaces and subtle borders, matching the Omarchy desktop
- **Catppuccin Mocha** dark theme by default; reads live Omarchy theme from `~/.local/state/omarchy/current/theme/colors.toml` on startup
- **Preview pane** — shows exactly what will be installed/upgraded/removed before any commit; cascade orphans and required-by dependencies are individually toggleable
- **Progress panel** — shows real-time transaction progress with package name
- **Error banner** — non-intrusive inline errors with dismiss

### Architecture
- **Two-process**: the Qt GUI (`omarchy-software`) spawns a long-lived Rust worker (`omarchy-software-core`) and communicates over newline-delimited JSON on stdin/stdout
- **Qt bridge** (`bridge.cpp`/`bridge.h`) — Qt properties and invokable methods connect QML to the worker protocol (`search`, `installed`, `preview_install`, `commit`, etc.)
- **Rust core** (`alpm_db.rs`, `transaction.rs`, `aur.rs`, `theme.rs`, `config.rs`, `process.rs`) — pure business logic, no Qt dependency
- **Polkit** for privilege escalation (not sudo) — pacman operations run as the unprivileged user via `pkexec`

---

## Building

```bash
# Requires: Rust 1.98.1, Qt 6.4+, CMake 3.22+, gcc/clang

git clone https://github.com/benclawbot/omarchy-software
cd omarchy-software

cmake -B build -DCMAKE_BUILD_TYPE=Release
cmake --build build
```

The build produces two binaries:

| Binary | Language | Role |
|--------|----------|------|
| `omarchy-software` | C++/Qt6 | GUI panel |
| `omarchy-software-core` | Rust | Package database worker |

Install system-wide (requires root):

```bash
cmake --install build
```

---

## Configuration

**Omarchy theme** is read automatically on startup:

```
~/.local/state/omarchy/current/theme/colors.toml
```

If absent, falls back to Catppuccin Mocha dark defaults.

**Protected packages** (removal blocked by the GUI and worker):

```
pacman, glibc, systemd, kernel, base, base-devel,
linux, linux-headers, linux-lts, linux-zen,
mkinitcpio, pacman-mirrors
```

---

## Supported Sources

| Source | Status | Backend |
|--------|--------|---------|
| Enabled pacman sync repositories | ✅ Ready | `libalpm` v5 |
| AUR | ✅ RPC ready, build TBD | `aur` v0.2 crate |
| CachyOS repos | ✅ Ready | `libalpm` v5 |

Flatpak/Snap are out of scope for v1.

---

## Protocol Reference

The GUI speaks JSON lines to the Rust worker over stdin/stdout:

| Operation | Description |
|-----------|-------------|
| `search { query, source, repository, category }` | Browse or search all enabled repositories and/or AUR, with repository and package-group filters |
| `installed { filter, sort, reverse }` | List installed packages |
| `updates {}` | Check for available updates |
| `refresh {}` | Refresh sync databases |
| `preview_install { packages, sources }` | Stage repository package installs |
| `preview_remove { packages }` | Stage removal with cascade/required-by |
| `commit { preview }` | Execute the reviewed repository transaction through polkit |
| `cache_clean { mode }` | Clean pacman cache (`keep_last` or `all`) |
| `aur_info { packages }` | Fetch AUR metadata |
| `theme {}` | Get current colour theme |
| `cancel {}` / `cancel_preview {}` | Interrupt or clear preview |
| `quit {}` | Shutdown worker |

---

## Project Structure

```
omarchy-software/
├── Cargo.toml               Rust dependencies + profile
├── CMakeLists.txt           Qt build + Cargo integration
├── rust-toolchain.toml      Rust 1.98.1 pinned
│
├── src/                     Rust core (no Qt dependency)
│   ├── main.rs              Worker entry + JSON protocol
│   ├── alpm_db.rs          libalpm read/write/transactions
│   ├── aur.rs               AUR HTTP RPC via aur crate
│   ├── transaction.rs       Preview staging + cache management
│   ├── theme.rs            Toml theme loader + Catppuccin fallback
│   ├── config.rs           Protected package list
│   └── process.rs          Cancellation and buffer management
│
├── ui/                      Qt6 / QML UI
│   ├── main.cpp             QGuiApplication entry
│   ├── bridge.cpp / .h      CXX-Qt typed bridge
│   ├── Main.qml             Root panel + navigation
│   ├── PackageCard.qml      Individual package card
│   ├── PackageList.qml      Virtual scrolling list
│   ├── FilterComboBox.qml   Repository and category selectors
│   ├── PreviewPane.qml      Pre-apply diff view
│   ├── ProgressPanel.qml    Transaction progress
│   ├── SearchBar.qml        Search input
│   ├── SourceBadge.qml      Colour-coded source pill
│   ├── UpdatesView.qml      Update list view
│   ├── InstalledView.qml   Installed package removal view
│   ├── BrowseView.qml      Repository install search + results
│   ├── ErrorBanner.qml      Inline error display
│   ├── Theme.qml            Shared QML theme values
│   └── omarchy-logo.svg     App icon
│
├── packaging/
│   ├── io.github.tcballard.Software.desktop
│   ├── io.github.tcballard.Software.svg
│   └── bindings.lua.example Hippo/lispe bindings
│
└── LICENSE                  MIT
```

---

## AUR Build Note

AUR package metadata is searched through the AUR RPC. Repository packages are managed through libalpm; AUR build and install support is not yet implemented.
