#!/usr/bin/env python3
"""One-time converter: ohmychadwm .h theme files → universal JSON themes."""

import json
import os
import re
import colorsys
import sys

THEME_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "themes")


def hex_to_hsl(hex_color):
    """Convert #RRGGBB to (hue 0-360, sat 0-1, light 0-1)."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
    h, l, s = colorsys.rgb_to_hls(r, g, b)
    return h * 360, s, l


def classify_color(hex_color):
    """Classify a hex color into a named category by hue."""
    hue, sat, light = hex_to_hsl(hex_color)
    # Skip near-gray colors (low saturation) or very dark/light
    if sat < 0.15 or light < 0.1 or light > 0.95:
        return None
    if hue < 15 or hue >= 345:
        return "red"
    elif hue < 35:
        return "orange"
    elif hue < 80:
        return "yellow"
    elif hue < 165:
        return "green"
    elif hue < 195:
        return "cyan"
    elif hue < 260:
        return "blue"
    elif hue < 295:
        return "purple"
    else:
        return "pink"


def darken(hex_color, amount=0.15):
    """Darken a hex color by a factor."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
    r = max(0, r - amount)
    g = max(0, g - amount)
    b = max(0, b - amount)
    return "#{:02x}{:02x}{:02x}".format(int(r * 255), int(g * 255), int(b * 255))


def lighten(hex_color, amount=0.1):
    """Lighten a hex color by a factor."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
    r = min(1, r + amount)
    g = min(1, g + amount)
    b = min(1, b + amount)
    return "#{:02x}{:02x}{:02x}".format(int(r * 255), int(g * 255), int(b * 255))


def parse_h_file(filepath):
    """Parse an ohmychadwm .h file and return a dict of variable → hex color."""
    colors = {}
    comment = ""
    with open(filepath) as f:
        for line in f:
            # Grab first comment as description
            if not comment and line.strip().startswith("/*"):
                comment = line.strip().strip("/*").strip("*/").strip()
            m = re.match(
                r'static\s+const\s+char\s+(\w+)\[\]\s*=\s*"(#[0-9a-fA-F]{6})"',
                line.strip(),
            )
            if m:
                colors[m.group(1)] = m.group(2).lower()
    return colors, comment


def luminance(hex_color):
    """Relative luminance of a hex color (0=black, 1=white)."""
    h = hex_color.lstrip("#")
    r, g, b = int(h[0:2], 16) / 255, int(h[2:4], 16) / 255, int(h[4:6], 16) / 255
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def extract_palette(colors):
    """Extract universal palette from ohmychadwm color variables."""
    bg = colors.get("SchemeNormbg", colors.get("col_borderbar", "#1e1e1e"))
    border_bar = colors.get("col_borderbar", bg)
    # bg_dark: prefer col_borderbar if darker, else darken bg
    bg_dark = border_bar if luminance(border_bar) <= luminance(bg) else darken(bg)
    if bg_dark == bg:
        bg_dark = darken(bg, 0.05)
    bg_alt = colors.get("SchemeNormbr", colors.get("TabSelbg", lighten(bg, 0.08)))
    if bg_alt == bg:
        bg_alt = lighten(bg, 0.08)

    # Pick fg/fg_dim: the brighter of SchemeNormfg and SchemeTitlefg is fg
    norm_fg = colors.get("SchemeNormfg", "#888888")
    title_fg = colors.get("SchemeTitlefg", colors.get("SchemeSelfg", "#f8f8f2"))
    if luminance(norm_fg) > luminance(title_fg):
        fg, fg_dim = norm_fg, title_fg
    else:
        fg, fg_dim = title_fg, norm_fg
    # But if fg_dim is too dark (close to bg), use SchemeTagfg instead
    if abs(luminance(fg_dim) - luminance(bg)) < 0.05:
        fg_dim = colors.get("SchemeTagfg", fg_dim)

    accent = colors.get("SchemeSelbg", colors.get("SchemeSelbr", "#bd93f9"))

    # Collect unique accent colors from tag foregrounds and buttons
    accent_keys = [f"SchemeTag{i}fg" for i in range(1, 11)]
    accent_keys += ["SchemeBtnClosefg", "SchemeBtnPrevfg", "SchemeBtnNextfg",
                     "SchemeLayoutfg", "SchemeSelbg", "SchemeSelbr"]
    unique_accents = {}
    for key in accent_keys:
        if key in colors:
            c = colors[key]
            cat = classify_color(c)
            if cat and cat not in unique_accents:
                unique_accents[cat] = c

    palette = {
        "bg": bg,
        "bg_dark": bg_dark,
        "bg_alt": bg_alt,
        "fg": fg,
        "fg_dim": fg_dim,
        "accent": accent,
    }

    # Map classified colors, with fallbacks
    for name in ["red", "green", "yellow", "blue", "orange", "pink", "purple", "cyan"]:
        palette[name] = unique_accents.get(name, accent)

    return palette


def convert_file(filepath, out_dir):
    """Convert a single .h file to universal JSON."""
    basename = os.path.splitext(os.path.basename(filepath))[0]
    theme_id = basename.lower().replace(" ", "-").replace("_", "-")
    # Title case the name, handle special names
    name = basename.replace("-", " ").replace("_", " ").title()

    colors, comment = parse_h_file(filepath)
    if not colors:
        print(f"  SKIP {basename} (no colors found)")
        return None

    palette = extract_palette(colors)
    theme = {
        "name": name,
        "id": theme_id,
        "description": comment,
        "palette": palette,
    }

    out_path = os.path.join(out_dir, f"{theme_id}.json")
    with open(out_path, "w") as f:
        json.dump(theme, f, indent=2)
    return theme_id


def main():
    if len(sys.argv) < 2:
        print("Usage: convert-ohmychadwm.py <path-to-ohmychadwm-themes-dir>")
        print("  e.g.: convert-ohmychadwm.py /tmp/ohmychadwm/etc/skel/.config/ohmychadwm/chadwm/themes/")
        sys.exit(1)

    src_dir = sys.argv[1]
    os.makedirs(THEME_DIR, exist_ok=True)

    h_files = sorted(f for f in os.listdir(src_dir) if f.endswith(".h"))
    print(f"Converting {len(h_files)} theme files from {src_dir}")

    converted = 0
    for hf in h_files:
        tid = convert_file(os.path.join(src_dir, hf), THEME_DIR)
        if tid:
            print(f"  OK {tid}")
            converted += 1

    print(f"\nConverted {converted}/{len(h_files)} themes to {THEME_DIR}")


if __name__ == "__main__":
    main()
