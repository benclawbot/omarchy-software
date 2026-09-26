#!/usr/bin/env bash
# install.sh — Build and install omarchy-software system-wide.
#
# Usage:
#   ./install.sh                # Build + install with pkexec prompts
#   ./install.sh --no-build     # Skip build, just install (uses existing build/)
#   ./install.sh --user         # Install to ~/.local instead of /usr
#
# Idempotent: safe to re-run.
#
# Note: uses pkexec (polkit) for individual privileged operations rather than
# escalating the whole script, so each step gets its own fingerprint/password
# popup on your desktop session.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
USER_INSTALL=false
NO_BUILD=false

# Run a command with polkit authentication. Falls back to sudo if pkexec is
# unavailable. Each invocation pops up its own fingerprint/password dialog.
run_root() {
  if command -v pkexec >/dev/null 2>&1; then
    pkexec "$@"
  else
    sudo "$@"
  fi
}

# Same as run_root, but for shell built-ins (no exec).
run_root_sh() {
  if command -v pkexec >/dev/null 2>&1; then
    pkexec /bin/sh -c "$*"
  else
    sudo /bin/sh -c "$*"
  fi
}

for arg in "$@"; do
  case "$arg" in
    --user)     USER_INSTALL=true ;;
    --no-build) NO_BUILD=true ;;
    -h|--help)
      sed -n '2,14p' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── System dependencies (Arch / Omarchy) ────────────────────────────────────
if command -v pacman >/dev/null 2>&1 && [[ "$USER_INSTALL" == false ]]; then
  echo "Checking system dependencies..."
  MISSING=()
  # qt6-declarative includes QtQuick.Controls / Controls2
  for pkg in qt6-base qt6-declarative cmake; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
      MISSING+=("$pkg")
    fi
  done
  # Cargo via rustup (in ~/.cargo) is preferred on Omarchy — don't reinstall
  if ! command -v cargo >/dev/null 2>&1; then
    if ! pacman -Q rust >/dev/null 2>&1; then
      MISSING+=("rust")
    fi
  fi
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Missing packages: ${MISSING[*]}"
    echo "→ Triggering pkexec prompt to install them..."
    run_root pacman -S --needed --noconfirm "${MISSING[@]}"
  fi
fi

# ── Build ───────────────────────────────────────────────────────────────────
if [[ "$NO_BUILD" == false ]]; then
  echo "Building (no root required)..."
  PREFIX="$([[ "$USER_INSTALL" == true ]] && echo "$HOME/.local" || echo "/usr")"
  cmake -S "$REPO_ROOT" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$PREFIX"
  cmake --build "$BUILD_DIR" --parallel
fi

# ── Install ─────────────────────────────────────────────────────────────────
echo "Installing..."
if [[ "$USER_INSTALL" == true ]]; then
  DESTDIR="$HOME/.local/stow/omarchy-software"
  cmake --install "$BUILD_DIR" --prefix "$DESTDIR"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$DESTDIR/bin/omarchy-software"     "$HOME/.local/bin/"
  ln -sf "$DESTDIR/bin/omarchy-software-tui" "$HOME/.local/bin/"
  echo "Installed to $HOME/.local/bin"
else
  echo "→ Triggering pkexec prompt to install system-wide..."
  run_root cmake --install "$BUILD_DIR"
fi

# ── Desktop database refresh (root) ─────────────────────────────────────────
if command -v update-desktop-database >/dev/null 2>&1 && [[ "$USER_INSTALL" == false ]]; then
  run_root_sh "update-desktop-database /usr/share/applications/ 2>/dev/null; gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null; true" || true
fi

# ── Hyprland quick-access bindings (user, no root) ──────────────────────────
BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
GUI_KEY="SUPER + SHIFT + A"
TUI_KEY="SUPER + SHIFT + I"

if [[ -f "$BINDINGS_FILE" ]]; then
  if ! grep -q "omarchy-software" "$BINDINGS_FILE"; then
    cp "$BINDINGS_FILE" "$BINDINGS_FILE.bak.$(date +%s)"
    cat >> "$BINDINGS_FILE" <<EOF

-- ─── omarchy-software ──────────────────────────────────────────────────────
hl.unbind("$GUI_KEY")
hl.unbind("$TUI_KEY")
o.bind("$GUI_KEY", "Package Manager", "omarchy-software")
o.bind("$TUI_KEY", "Packages (TUI)", { tui = "omarchy-software-tui", focus = true })
EOF
    echo "Hyprland bindings added: $GUI_KEY → GUI, $TUI_KEY → TUI"
  else
    echo "Hyprland bindings already present — skipping"
  fi
else
  echo "Hyprland bindings.lua not found at $BINDINGS_FILE — skipping keybinding setup"
  echo "  (copy packaging/bindings.lua.example manually if needed)"
fi

# ── Omarchy hook for re-install prompt (user, no root) ──────────────────────
HOOK_DIR="$HOME/.config/omarchy/hooks/post-update.d"
if [[ -d "$HOOK_DIR" ]]; then
  HOOK_FILE="$HOOK_DIR/omarchy-software.hook"
  if [[ ! -f "$HOOK_FILE" ]]; then
    cat > "$HOOK_FILE" <<EOF
#!/bin/bash
set -e
if omarchy-done ensure omarchy-software-install; then
  omarchy-notification-send -u normal -g 󰏖 "Omarchy Software installed" \\
    "Click to install or update the GUI/TUI package manager." \\
    --exec omarchy-launch-floating-terminal-with-presentation $REPO_ROOT/install.sh
fi
EOF
    chmod +x "$HOOK_FILE"
    echo "Omarchy post-update hook installed at $HOOK_FILE"
  fi
fi

echo ""
echo "✓ omarchy-software installed successfully"
echo ""
echo "Quick access:"
echo "  GUI → $GUI_KEY"
echo "  TUI → $TUI_KEY"
echo ""
echo "Or launch from app menu: 'Omarchy Software' / 'Omarchy Software (TUI)'"
