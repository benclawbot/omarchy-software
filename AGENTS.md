# Omarchy Software — AGENTS.md

## Project overview

Omarchy Software is a native GUI package manager for Arch Linux, built for the
Omarchy desktop. It speaks directly to libalpm for repo operations and the AUR
RPC for AUR queries, presenting a polished floating panel with the Catppuccin
Mocha palette and Omarchy theme integration.

## Tech stack

- **Backend**: Rust 1.98.1, `alpm` crate for libalpm, `aur` crate for AUR RPC,
  `tokio` for async, `serde`/`serde_json` for JSON protocol
- **Frontend**: C++ with Qt6 Quick/QML, CXX-Qt bridge pattern
- **Build**: CMake + Cargo (Rust compiled first, Qt links against the binary)
- **Theme**: reads `~/.local/state/omarchy/current/theme/colors.toml` at startup

## Build and run

```bash
sudo pacman -S --needed git base-devel cmake ninja rust cargo qt6-base \
  qt6-declarative qt6-wayland qt6-svg python desktop-file-utils alpm

git clone https://github.com/tcballard/omarchy-software.git
cd omarchy-software
cmake -S . -B build -G Ninja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX=/usr \
  -DCMAKE_INSTALL_LIBDIR=lib
cmake --build build -j 4
./build/omarchy-software
```

## Architecture

```
Main.qml (QML UI)
    ↓ JSON over Unix pipe
bridge.cpp / bridge.h (Qt C++ bridge)
    ↓ JSON over stdin/stdout
main.rs (Rust worker)
    ├── alpm_db.rs   — libalpm wrapper (search, install, remove, check updates)
    ├── aur.rs       — AUR RPC HTTP client (search, info)
    ├── transaction.rs — transaction preview and cache management
    ├── theme.rs     — Omarchy theme loader
    └── config.rs    — XDG config (protected packages, ignored packages)
```

## Protocol

Each request is one JSON object per line on stdin; responses are one JSON object
per line on stderr.

```
{ "op": "search",   "query": "firefox", "source": "all" }
{ "op": "installed", "filter": "all", "sort": "size", "reverse": true }
{ "op": "updates" }
{ "op": "refresh" }
{ "op": "preview_install", "packages": ["firefox"], "sources": ["repo"] }
{ "op": "preview_remove",  "packages": ["firefox"] }
{ "op": "commit",    "preview": { ... } }
{ "op": "cache_clean", "mode": "keep_last" }
{ "op": "cancel_preview" }
{ "op": "cancel" }
{ "op": "theme" }
{ "op": "quit" }
```

## Colour system

Source colours (shown as badges on every package card):

| Source | Hex | Badge |
|--------|-----|-------|
| Repository | `#89b4fa` | Blue |
| AUR | `#cba6f7` | Magenta |
| CachyOS | `#94e2d5` | Cyan |

Action colours:

| Action | Hex |
|--------|-----|
| Install | `#a6e3a1` (green) |
| Update | `#89b4fa` (blue) |
| Remove | `#f38ba8` (red) |
| Warning/cascade | `#f59cb5` (orange) |

## Source badge design

The SourceBadge component (`ui/SourceBadge.qml`) renders coloured pill badges
next to each package. Badge colours must stay visually distinct from each other
and from the action colours above — this is the primary safety affordance.

## Key invariants

- Never offer to remove packages in `protected_packages` (pacman, glibc, systemd, etc.)
- Always show a change preview before executing any install/remove
- The worker never runs as root; pacman operations go through polkit
- AUR search/info uses HTTPS to the AUR RPC; the build step uses the user's
  configured AUR helper (tries yay, then paru)
- Theme is loaded once at startup; the GUI does not hot-reload theme changes
  (close and reopen to pick up a new theme)

## Releasing

1. Bump the version in `Cargo.toml`, `CMakeLists.txt`, and `packaging/PKGBUILD`
2. `cargo build --release --locked`
3. Run tests: `ctest --test-dir build`
4. `./scripts/package-source.sh` → upload to GitHub Releases
5. Push tags: `git tag v0.x.y && git push --tags`
