#!/usr/bin/env bash
# Restore configs from the most recent backup

PICKER_DIR="$(cd "$(dirname "$0")" && pwd)"
BACKUP_BASE="$PICKER_DIR/backups"

if [ ! -d "$BACKUP_BASE" ]; then
    echo "No backups found."
    exit 1
fi

# Find most recent backup directory
latest=$(ls -1d "$BACKUP_BASE"/*/ 2>/dev/null | sort | tail -1)

if [ -z "$latest" ]; then
    echo "No backup directories found in $BACKUP_BASE"
    exit 1
fi

echo "Restoring from: $latest"
restored=0

# Map backup subdirectories back to their original locations
declare -A targets=(
    ["hyprland/colors.conf"]="$HOME/.config/hypr/dms/colors.conf"
    ["dms/theme.json"]=""  # skip — theme.json goes into a theme subdir
    ["dms/settings.json"]="$HOME/.config/DankMaterialShell/settings.json"
    ["noctalia/settings.json"]="$HOME/.config/noctalia/settings.json"
    ["dunst/dunstrc"]="$HOME/.config/dunst/dunstrc"
    ["rofi/config.rasi"]="$HOME/.config/rofi/config.rasi"
    ["swaync/style.css"]="$HOME/.config/swaync/style.css"
    ["chadwm/config.def.h"]="$HOME/.config/arco-chadwm/chadwm/config.def.h"
)

# Restore each backed up file
for backup_rel in "${!targets[@]}"; do
    src="$latest/$backup_rel"
    dest="${targets[$backup_rel]}"
    if [ -f "$src" ] && [ -n "$dest" ]; then
        cp "$src" "$dest"
        echo "  Restored: $dest"
        ((restored++))
    fi
done

# Also restore any .h theme files (skip config.def.h — already handled above)
for hfile in "$latest"/chadwm/*.h; do
    [ -f "$hfile" ] || continue
    bname=$(basename "$hfile")
    [ "$bname" = "config.def.h" ] && continue
    dest="$HOME/.config/arco-chadwm/chadwm/themes/$bname"
    cp "$hfile" "$dest"
    echo "  Restored: $dest"
    ((restored++))
done

# Also restore noctalia colorscheme JSONs
for nfile in "$latest"/noctalia/*.json; do
    [ -f "$nfile" ] || continue
    bname=$(basename "$nfile")
    [ "$bname" = "settings.json" ] && continue
    # Try to find matching directory
    for d in "$HOME/.config/noctalia/colorschemes"/*/; do
        if [ -f "$d/$bname" ]; then
            cp "$nfile" "$d/$bname"
            echo "  Restored: $d/$bname"
            ((restored++))
            break
        fi
    done
done

echo ""
echo "Restored $restored file(s)."

# Restart dunst and swaync
pkill dunst 2>/dev/null
timeout 3 swaync-client -rs 2>/dev/null

timeout 3 notify-send "Theme Picker" "Rolled back to previous theme ($restored files restored)" 2>/dev/null
