#!/usr/bin/env bash
# Universal theme picker — rofi (Wayland) with image previews, or dmenu (X11)

PICKER_DIR="$(cd "$(dirname "$0")" && pwd)"
THEME_DIR="$PICKER_DIR/themes"
PREVIEW_DIR="$PICKER_DIR/previews"
CURRENT_FILE="$PICKER_DIR/current-theme"

# Read current theme for marking
current=""
[ -f "$CURRENT_FILE" ] && current=$(cat "$CURRENT_FILE" | tr -d '[:space:]')

# Generate entries piped directly to rofi — null bytes can't survive in bash
# variables or sort, so we use printf and pipe straight through.
# Glob already returns alphabetical order, so no sort needed.
generate_entries() {
    for f in "$THEME_DIR"/*.json; do
        id=$(basename "$f" .json)
        name=$(python3 -c "import json; print(json.load(open('$f'))['name'])" 2>/dev/null)
        [ -z "$name" ] && name="$id"

        marker="  "
        [ "$id" = "$current" ] && marker="● "

        preview="$PREVIEW_DIR/$id.png"
        if [ -f "$preview" ]; then
            # Rofi dmenu icon protocol: text\0icon\x1fpath
            printf '%s%s (%s)\0icon\x1f%s\n' "$marker" "$name" "$id" "$preview"
        else
            printf '%s%s (%s)\n' "$marker" "$name" "$id"
        fi
    done
}

# Pick launcher based on session type
if [ "$XDG_SESSION_TYPE" = "wayland" ] || pgrep -x Hyprland >/dev/null 2>&1; then
    chosen=$(generate_entries | rofi -dmenu -i -p "Theme" \
        -show-icons \
        -theme-str '
            window { width: 90%; height: 80%; }
            listview { columns: 4; lines: 3; flow: horizontal; }
            element { orientation: vertical; padding: 10px; }
            element-icon { size: 250px; }
            element-text { horizontal-align: 0.5; }
        ')
else
    # dmenu fallback (no image support, strip icon markup)
    chosen=$(generate_entries | sed 's/\x00icon.*//g' | dmenu -i -l 20 -p "Theme:")
fi

[ -z "$chosen" ] && exit 0

# Extract theme id from "● Name (id)" or "  Name (id)"
theme_id=$(echo "$chosen" | grep -oP '\(([^)]+)\)' | tr -d '()')

if [ -z "$theme_id" ]; then
    notify-send "Theme Picker" "Could not parse theme selection"
    exit 1
fi

# Apply
python3 "$PICKER_DIR/apply-theme.py" "$theme_id"
