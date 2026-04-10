#!/usr/bin/env bash
# Keybind cheat sheet — parses Hyprland and chadwm configs, shows in rofi/dmenu

HYPR_BINDS="$HOME/.config/hypr/shared-binds.conf"
SXHKD_BINDS="$HOME/.config/arco-chadwm/sxhkd/sxhkdrc"

generate_entries() {
    local section=""

    # ── Parse Hyprland shared-binds.conf ──
    if [ -f "$HYPR_BINDS" ]; then
        while IFS= read -r line; do
            # Section headers: "# === Foo ==="
            if [[ "$line" =~ ^#\ ===\ (.+)\ === ]]; then
                section="${BASH_REMATCH[1]}"
                continue
            fi
            # Skip comments and empty lines
            [[ "$line" =~ ^#|^$ ]] && continue
            # Parse: bind = MODS, KEY, action, args
            #        bindel = MODS, KEY, exec, cmd
            if [[ "$line" =~ ^bind[a-z]*\ =\ ([^,]+),\ ([^,]+),\ ([^,]+)(,\ (.+))? ]]; then
                mods="${BASH_REMATCH[1]}"
                key="${BASH_REMATCH[2]}"
                action="${BASH_REMATCH[3]}"
                args="${BASH_REMATCH[5]}"

                # Clean up mods
                mods=$(echo "$mods" | sed 's/SUPER/Super/g; s/SHIFT/Shift/g; s/CTRL/Ctrl/g; s/ALT/Alt/g')
                key=$(echo "$key" | sed 's/^ *//; s/ *$//')

                # Build description
                if [ "$action" = "exec" ]; then
                    # Shorten long exec commands
                    desc=$(echo "$args" | sed 's|/home/[^/]*/\.config/||g; s|/home/[^/]*/||g' | cut -c1-50)
                else
                    desc="$action${args:+ $args}"
                fi

                combo="$mods + $key"
                printf "%-28s  │  %s  [%s]\n" "$combo" "$desc" "$section"
            fi
        done < "$HYPR_BINDS"
    fi

    # ── Parse sxhkdrc ──
    if [ -f "$SXHKD_BINDS" ] && pgrep -x chadwm >/dev/null 2>&1; then
        local comment="" combo=""
        while IFS= read -r line; do
            # Section headers
            if [[ "$line" =~ ^#{3,} ]]; then
                continue
            fi
            # Comments become descriptions
            if [[ "$line" =~ ^#(.+) ]]; then
                comment="${BASH_REMATCH[1]}"
                comment=$(echo "$comment" | sed 's/^ *//')
                continue
            fi
            # Keybind line (not indented)
            if [[ "$line" =~ ^[a-zA-Z] ]] && [[ ! "$line" =~ ^[[:space:]] ]]; then
                combo=$(echo "$line" | sed 's/super/Super/g; s/shift/Shift/g; s/ctrl/Ctrl/g; s/alt/Alt/g; s/ + / + /g')
                continue
            fi
            # Command line (indented) — follows a keybind
            if [[ "$line" =~ ^[[:space:]]+(.+) ]] && [ -n "$combo" ]; then
                cmd="${BASH_REMATCH[1]}"
                cmd=$(echo "$cmd" | sed 's|/home/[^/]*/\.config/||g; s|/home/[^/]*/||g' | cut -c1-50)
                desc="${comment:-$cmd}"
                printf "%-28s  │  %s  [chadwm]\n" "$combo" "$desc"
                combo=""
                comment=""
            fi
        done < "$SXHKD_BINDS"
    fi
}

# Show in rofi or dmenu
if [ "$XDG_SESSION_TYPE" = "wayland" ] || pgrep -x Hyprland >/dev/null 2>&1; then
    generate_entries | rofi -dmenu -i -p "Keybinds" \
        -theme-str '
            window { width: 800px; }
            listview { lines: 20; }
            element-text { font: "Hack 12"; }
        '
else
    generate_entries | dmenu -i -l 25 -p "Keybinds:"
fi
