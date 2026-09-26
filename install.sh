#!/usr/bin/env bash
# install.sh — Build and install omarchy-software system-wide.
#
# Usage:
#   ./install.sh                # Build + install with sudo prompt
#   ./install.sh --no-build     # Skip build, just install (uses existing build/)
#   ./install.sh --user         # Install to ~/.local instead of /usr
#
# Idempotent: safe to re-run.

set -euo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="${REPO_ROOT}/build"
USER_INSTALL=false
NO_BUILD=false

for arg in "$@"; do
  case "$arg" in
    --user)     USER_INSTALL=true ;;
    --no-build) NO_BUILD=true ;;
    -h|--help)
      sed -n '2,11p' "$0"
      exit 0
      ;;
    *) echo "Unknown argument: $arg"; exit 1 ;;
  esac
done

# ── Privilege escalation ────────────────────────────────────────────────────
if [[ "$USER_INSTALL" == false && "$EUID" -ne 0 ]]; then
  echo "Root required to install to /usr. Requesting sudo..."
  exec sudo -E -- "$0" "$@"
fi

# ── System dependencies (Arch / Omarchy) ────────────────────────────────────
if command -v pacman >/dev/null 2>&1 && [[ "$USER_INSTALL" == false ]]; then
  echo "Checking system dependencies..."
  MISSING=()
  for pkg in qt6-base qt6-declarative qt6-quickcontrols2 cmake cargo alpm; do
    if ! pacman -Q "$pkg" >/dev/null 2>&1; then
      MISSING+=("$pkg")
    fi
  done
  if [[ ${#MISSING[@]} -gt 0 ]]; then
    echo "Missing packages: ${MISSING[*]}"
    echo "Install them with: sudo pacman -S ${MISSING[*]}"
    read -rp "Install now? [Y/n] " ans
    if [[ ! "$ans" =~ ^[Nn]$ ]]; then
      sudo pacman -S --needed --noconfirm "${MISSING[@]}"
    fi
  fi
fi

# ── Build ───────────────────────────────────────────────────────────────────
if [[ "$NO_BUILD" == false ]]; then
  echo "Building..."
  cmake -S "$REPO_ROOT" -B "$BUILD_DIR" \
        -DCMAKE_BUILD_TYPE=Release \
        -DCMAKE_INSTALL_PREFIX="$([[ "$USER_INSTALL" == true ]] && echo "$HOME/.local" || echo "/usr")"
  cmake --build "$BUILD_DIR" --parallel
fi

# ── Install ─────────────────────────────────────────────────────────────────
echo "Installing..."
if [[ "$USER_INSTALL" == true ]]; then
  # Install to user prefix without needing root
  DESTDIR="$HOME/.local/stow/omarchy-software" \
    cmake --install "$BUILD_DIR" --prefix "$HOME/.local/stow/omarchy-software"
  mkdir -p "$HOME/.local/bin"
  ln -sf "$HOME/.local/stow/omarchy-software/bin/omarchy-software"     "$HOME/.local/bin/"
  ln -sf "$HOME/.local/stow/omarchy-software/bin/omarchy-software-tui" "$HOME/.local/bin/"
  echo "Installed to $HOME/.local/bin"
else
  cmake --install "$BUILD_DIR"
fi

# ── Desktop database refresh ────────────────────────────────────────────────
if command -v update-desktop-database >/dev/null 2>&1; then
  update-desktop-database /usr/share/applications/ 2>/dev/null || true
fi
if command -v gtk-update-icon-cache >/dev/null 2>&1; then
  gtk-update-icon-cache -f /usr/share/icons/hicolor 2>/dev/null || true
fi

# ── Hyprland quick-access bindings ──────────────────────────────────────────
BINDINGS_FILE="$HOME/.config/hypr/bindings.lua"
GUI_DESC="Package Manager"
TUI_DESC="Packages (TUI)"
GUI_KEY="SUPER + SHIFT + A"
TUI_KEY="SUPER + SHIFT + I"

if [[ -f "$BINDINGS_FILE" ]]; then
  echo "Adding Hyprland bindings to $BINDINGS_FILE..."

  # Backup once per install
  if ! grep -q "omarchy-software" "$BINDINGS_FILE"; then
    cp "$BINDINGS_FILE" "$BINDINGS_FILE.bak.$(date +%s)"

    cat >> "$BINDINGS_FILE" <<EOF

-- ─── omarchy-software ──────────────────────────────────────────────────────
hl.unbind("$GUI_KEY")
hl.unbind("$TUI_KEY")
o.bind("$GUI_KEY", "$GUI_DESC", "omarchy-software")
o.bind("$TUI_KEY", "$TUI_DESC", { tui = "omarchy-software-tui", focus = true })
EOF
    echo "Bindings added: $GUI_KEY → GUI, $TUI_KEY → TUI"
  else
    echo "Bindings already present — skipping"
  fi
else
  echo "Hyprland bindings.lua not found at $BINDINGS_FILE"
  echo "Manually copy packaging/bindings.lua.example into your Hyprland config."
fi

# ── Omarchy hook for re-installation prompt ─────────────────────────────────
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
