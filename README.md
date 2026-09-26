# omarchy-software

A native GUI package manager for [Omarchy](https://github.com/omarchy/omarchy) — Arch Linux with a floating glass desktop. Built with Rust + Qt6 QML + a CXX-Qt bridge, matching the omarchy-task-manager stack exactly.

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
- **Multi-select operations** — checkbox multi-select, shift+click range, ctrl+click toggle
- **Change preview before Apply** — always shown; cascade removals and Required-By dependencies surfaced in orange/red with per-item checkboxes to deselect before committing
- **Protected packages** — pacman, glibc, systemd, kernel, base and other critical packages are GUI-protected from removal

### Views
| Tab | Description |
|-----|-------------|
| **Browse** | Search repos + AUR simultaneously; source badges on every result |
| **Installed** | Filter by explicit/dependency/orphan; sort by name/size/date |
| **Updates** | Check all repos and AUR for available updates |
| **Cache** | Clean the pacman package cache (keep last, or all) |

### UX
- **Source badges** — every package card shows a colour-coded pill:
  - <span style="color:#89b4fa">●</span> Blue — official repo
  - <span style="color:#cba6f7">●</span> Magenta — AUR
  - <span style="color:#94e2d5">●</span> Cyan — CachyOS repo
- **Glass panel aesthetic** — `rgba(30, 30, 46, 0.82)` background with subtle borders, matching the Omarchy desktop
- **Catppuccin Mocha** dark theme by default; reads live Omarchy theme from `~/.local/state/omarchy/current/theme/colors.toml` on startup
- **Preview pane** — shows exactly what will be installed/upgraded/removed before any commit; cascade orphans and required-by dependencies are individually toggleable
- **Progress panel** — shows real-time transaction progress with package name
- **Error banner** — non-intrusive inline errors with dismiss

### Architecture
- **Two-process**: the Qt GUI (`omarchy-software`) spawns a long-lived Rust worker (`omarchy-software-core`) and communicates over a Unix socket via JSON lines (stdin/stdout)
- **CXX-Qt bridge** (`bridge.cpp`/`bridge.h`) — typed Qt ↔ Rust bindings; protocol methods map 1:1 to `main.rs` operations (`search`, `installed`, `preview_install`, `commit`, etc.)
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

**Protected packages** (GUI removal blocked):

```
pacman, glibc, systemd, kernel, base, base-devel,
linux, linux-headers, linux-lts, linux-zen,
mkinitcpio, pacman-mirrors
```

---

## Supported Sources

| Source | Status | Backend |
|--------|--------|---------|
| Official repos (core/extra/community/multilib) | ✅ Ready | `libalpm` v5 |
| AUR | ✅ RPC ready, build TBD | `aur` v0.2 crate |
| CachyOS repos | ✅ Ready | `libalpm` v5 |

Flatpak/Snap are out of scope for v1.

---

## Protocol Reference

The GUI speaks JSON lines to the Rust worker over stdin/stdout:

| Operation | Description |
|-----------|-------------|
| `search { query, source }` | Search repo and/or AUR |
| `installed { filter, sort, reverse }` | List installed packages |
| `updates {}` | Check for available updates |
| `refresh {}` | Refresh sync databases |
| `preview_install { packages, sources }` | Stage repo + AUR installs |
| `preview_remove { packages }` | Stage removal with cascade/required-by |
| `commit { preview }` | Execute staged transaction |
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
│   └── process.rs          Socket setup, cancellation, buffer
│
├── ui/                      Qt6 / QML UI
│   ├── main.cpp             QGuiApplication entry
│   ├── bridge.cpp / .h      CXX-Qt typed bridge
│   ├── Main.qml             Root panel + navigation
│   ├── PackageCard.qml      Individual package card
│   ├── PackageList.qml      Virtual scrolling list
│   ├── PreviewPane.qml      Pre-apply diff view
│   ├── ProgressPanel.qml    Transaction progress
│   ├── SearchBar.qml        Search input
│   ├── SourceBadge.qml      Colour-coded source pill
│   ├── UpdatesView.qml      Update list view
│   ├── InstalledView.qml   Installed list view
│   ├── CacheView.qml       Cache cleaner view
│   ├── BrowseView.qml      Search + results
│   ├── ErrorBanner.qml      Inline error display
│   ├── Theme.js             QML colour helpers
│   └── omarchy-logo.svg     App icon
│
├── packaging/
│   ├── io.github.benclawbot.Software.desktop
│   ├── io.github.benclawbot.Software.svg
│   └── bindings.lua.example Hippo/lispe bindings
│
└── LICENSE                  MIT
```

---

## AUR Build Note

AUR package installation currently fetches metadata via RPC. Actual building from PKGBUILD is **not yet implemented** — it will require an external helper (e.g. paru/pakku) invoked via `pkexec`, or a native `makepkg` runner. Tracking in [#3](https://github.com/benclawbot/omarchy-software/issues/3).
