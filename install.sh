#!/usr/bin/env bash
# Universal Theme Picker — Install Script
# Clone this repo, run ./install.sh, and you're set.

set -e

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
INSTALL_DIR="$HOME/.config/theme-picker"

# ── Colors for output ─────────────────────────────────────────────────────────
green() { printf '\033[32m%s\033[0m\n' "$*"; }
yellow() { printf '\033[33m%s\033[0m\n' "$*"; }
red() { printf '\033[31m%s\033[0m\n' "$*"; }

# ── Check dependencies ────────────────────────────────────────────────────────
missing=()
command -v python3 >/dev/null || missing+=(python3)
command -v rofi >/dev/null || { command -v dmenu >/dev/null || missing+=(rofi); }

if [ ${#missing[@]} -gt 0 ]; then
    red "Missing dependencies: ${missing[*]}"
    echo "Install them first (e.g. pacman -S ${missing[*]})"
    exit 1
fi

# ── Install theme-picker ─────────────────────────────────────────────────────
if [ "$SCRIPT_DIR" != "$INSTALL_DIR" ]; then
    echo "Symlinking $SCRIPT_DIR → $INSTALL_DIR"
    mkdir -p "$(dirname "$INSTALL_DIR")"
    ln -sfn "$SCRIPT_DIR" "$INSTALL_DIR"
else
    echo "Already at $INSTALL_DIR"
fi

chmod +x "$SCRIPT_DIR"/{theme-picker.sh,apply-theme.py,rollback.sh,convert-ohmychadwm.py}
mkdir -p "$INSTALL_DIR/backups"

green "Theme picker installed at $INSTALL_DIR"

# ── Inject Super+T keybind into detected WMs ─────────────────────────────────
PICKER_CMD="$INSTALL_DIR/theme-picker.sh"
injected=()

# Hyprland (shared-binds.conf or hyprland.conf)
for hconf in "$HOME/.config/hypr/shared-binds.conf" "$HOME/.config/hypr/hyprland.conf"; do
    if [ -f "$hconf" ]; then
        if ! grep -q "theme-picker" "$hconf" 2>/dev/null; then
            printf '\n# === Theme Picker ===\nbind = SUPER, T, exec, %s\n' "$PICKER_CMD" >> "$hconf"
            injected+=("Hyprland ($hconf)")
        else
            yellow "Hyprland: Super+T already configured in $hconf"
        fi
        break
    fi
done

# chadwm (sxhkdrc)
SXHKD="$HOME/.config/arco-chadwm/sxhkd/sxhkdrc"
if [ -f "$SXHKD" ]; then
    if ! grep -q "theme-picker" "$SXHKD" 2>/dev/null; then
        printf '\n#Theme Picker\nsuper + t\n    %s\n' "$PICKER_CMD" >> "$SXHKD"
        injected+=("chadwm ($SXHKD)")
    else
        yellow "chadwm: Super+T already configured in $SXHKD"
    fi
fi

# i3 / sway
for wm_conf in "$HOME/.config/i3/config" "$HOME/.config/sway/config"; do
    if [ -f "$wm_conf" ]; then
        if ! grep -q "theme-picker" "$wm_conf" 2>/dev/null; then
            printf '\n# Theme Picker\nbindsym $mod+t exec %s\n' "$PICKER_CMD" >> "$wm_conf"
            injected+=("$(basename "$(dirname "$wm_conf")") ($wm_conf)")
        else
            yellow "$(basename "$(dirname "$wm_conf")"): Super+T already configured"
        fi
    fi
done

if [ ${#injected[@]} -gt 0 ]; then
    green "Added Super+T keybind to: ${injected[*]}"
else
    yellow "No new keybinds added (already configured or no supported WM config found)"
fi

# ── Summary ───────────────────────────────────────────────────────────────────
echo ""
green "Done! Theme picker is ready."
echo "  Super+T      — open theme picker"
echo "  Themes:        $INSTALL_DIR/themes/ ($(ls "$INSTALL_DIR/themes/"*.json 2>/dev/null | wc -l) themes)"
echo "  Previews:      $INSTALL_DIR/previews/ ($(ls "$INSTALL_DIR/previews/"*.png 2>/dev/null | wc -l) images)"
echo "  Apply:         $INSTALL_DIR/apply-theme.py <theme-id>"
echo "  Rollback:      $INSTALL_DIR/rollback.sh"
