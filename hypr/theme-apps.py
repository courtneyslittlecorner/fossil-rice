#!/usr/bin/env python3
"""Generate app colors from a Quickshell theme in ~/.config/quickshell/Config.qml.

Usage: theme-apps.py THEME_NAME
  -> writes ~/.config/kitty/current-theme.conf  (terminal colors)
  -> writes ~/.config/mako/config               (notification style)
Called by theme-sync.sh whenever the theme changes.
"""
import colorsys, os, re, sys

HOME = os.path.expanduser("~")
QML = os.path.join(HOME, ".config/quickshell/Config.qml")
KITTY_OUT = os.path.join(HOME, ".config/kitty/current-theme.conf")
MAKO_OUT = os.path.join(HOME, ".config/mako/config")
OPACITY = 0.92  # solid dark background, as you had in hades.conf


def load_theme(name):
    src = open(QML).read()
    m = re.search(r'^\s*"%s": \{(.*?)^\s*\}' % re.escape(name), src, re.S | re.M)
    if not m:
        sys.exit(f"theme {name!r} not found in {QML}")
    return dict(re.findall(r'"(\w+)": "(#[0-9a-fA-F]{6})"', m.group(1)))


def rgb(h):
    h = h.lstrip("#")
    return [int(h[i:i + 2], 16) / 255 for i in (0, 2, 4)]


def hx(c):
    return "#" + "".join(f"{round(max(0, min(1, v)) * 255):02x}" for v in c)


def mix(a, b, t):
    """t=0 -> a, t=1 -> b"""
    return hx([x + (y - x) * t for x, y in zip(rgb(a), rgb(b))])


def lift(h, amount):
    """Brighten a color for the 'bright' ANSI variants."""
    hh, l, s = colorsys.rgb_to_hls(*rgb(h))
    return hx(colorsys.hls_to_rgb(hh, min(0.9, l + amount), s))


def hue_color(hue_deg, tint, light=0.66, sat=0.42):
    """A muted color at the given hue, nudged toward the theme accent."""
    base = hx(colorsys.hls_to_rgb(hue_deg / 360, light, sat))
    return mix(base, tint, 0.2)


def write(path, text):
    tmp = path + ".tmp"
    with open(tmp, "w") as fh:
        fh.write(text)
    os.replace(tmp, path)


def kitty(name, t):
    base, fg, accent = t["base"], t["textLight"], t["accent"]
    hi = t.get("highlight", mix(base, fg, 0.15))

    # Prefer the theme's own semantic colors; generate the rest in its style.
    ansi = {
        "red":     t.get("danger") or hue_color(355, accent),
        "green":   hue_color(95, accent),
        "yellow":  t.get("warning") or hue_color(45, accent),
        "blue":    hue_color(220, accent),
        "magenta": hue_color(300, accent),
        "cyan":    t.get("humorCold") or hue_color(185, accent),
    }
    order = ["red", "green", "yellow", "blue", "magenta", "cyan"]

    lines = [
        f"# Generated from the Quickshell '{name}' theme by ~/.config/hypr/theme-apps.py.",
        "# Don't edit: it's overwritten on every theme change.",
        f"background_opacity {OPACITY}",
        f"background           {base}",
        f"foreground           {fg}",
        f"cursor               {accent}",
        f"cursor_text_color    {base}",
        f"selection_background {accent}",
        f"selection_foreground {base}",
        f"url_color            {accent}",
        f"active_border_color   {accent}",
        f"inactive_border_color {hi}",
        f"active_tab_background   {accent}",
        f"active_tab_foreground   {base}",
        f"inactive_tab_background {hi}",
        f"inactive_tab_foreground {fg}",
        f"tab_bar_background      {base}",
        f"color0               {hi}",
        f"color8               {mix(base, fg, 0.45)}",
        f"color7               {mix(fg, base, 0.2)}",
        f"color15              {fg}",
    ]
    for i, key in enumerate(order, start=1):
        lines.append(f"color{i:<15}{ansi[key]}")
        lines.append(f"color{i + 8:<15}{lift(ansi[key], 0.08)}")

    write(KITTY_OUT, "\n".join(lines) + "\n")


def mako(name, t):
    base, fg, accent = t["base"], t["textLight"], t["accent"]
    accent_dark = t.get("accentDark", mix(accent, base, 0.45))
    urgent = t.get("urgent", t.get("danger", accent))
    write(MAKO_OUT, f"""# Linux Antiquity — mako notification theme.
# Generated from the Quickshell '{name}' theme by ~/.config/hypr/theme-apps.py.
# Don't edit colors here: this file is overwritten on every theme change.
# Layout settings live in theme-apps.py (the mako() function).

max-visible=5
sort=-time
anchor=top-right

width=370
height=140
margin=12
padding=15
border-size=1
border-radius=9

font=sans-serif 11

# base with slight transparency / textLight / accentDark
background-color={base}f0
text-color={fg}
border-color={accent_dark}
# accent
progress-color=over {accent}

default-timeout=6000

[urgency=high]
# urgent orange border so it stands out, and no timeout.
border-color={urgent}
text-color={accent}
default-timeout=0

[urgency=low]
# accentDark, quieter and quicker to leave.
text-color={accent_dark}
default-timeout=4000
""")


def main():
    name = sys.argv[1]
    t = load_theme(name)
    kitty(name, t)
    mako(name, t)


if __name__ == "__main__":
    main()
