#!/usr/bin/env bash
# Make the desktop match the Quickshell theme: window borders, kitty colors,
# notifications (mako), mouse cursor, app icons.
# Usage: theme-sync.sh THEME_NAME BASE_HEX ACCENT_HEX HIGHLIGHT_HEX
# Called by ~/.config/quickshell/Config.qml whenever the theme changes.
set -euo pipefail

theme="$1" base="$2" accent="$3" highlight="$4"
size=40
src="$HOME/.local/share/icons/Gauntlet-Source"  # built by make_gauntlet_cursor.py (Bibata + gauntlet hands)
icons="$HOME/.local/share/icons"
state="$HOME/.config/hypr/theme-state"
cursor="${theme^}-Cursor"
active="rgb(${accent#\#})"       # focused window border
inactive="rgb(${highlight#\#})"  # unfocused window border

exec 9>"${XDG_RUNTIME_DIR:-/tmp}/theme-sync.lock"
flock 9

# Borders first (instant).
hyprctl eval "hl.config({ general = { col = { active_border = \"$active\", inactive_border = \"$inactive\" } } })" >/dev/null

# Kitty + mako: regenerate their configs, then tell them to reload.
python3 "$HOME/.config/hypr/theme-apps.py" "$theme"
pkill -USR1 -x kitty 2>/dev/null || true
makoctl reload 2>/dev/null || true

# Cursor: (re)build only if missing or the theme's colors changed (~20s).
stamp="$src|$base|$accent"
if [[ "$(cat "$icons/$cursor/.colors" 2>/dev/null)" != "$stamp" ]]; then
    python3 "$icons/recolor_cursor.py" "$src" "$icons/$cursor" "$cursor" "$base" "$accent"
    echo "$stamp" > "$icons/$cursor/.colors"
    # Hyprland caches a theme by name; switch away first so the rebuilt files load.
    hyprctl setcursor Bibata-Modern-Classic "$size" >/dev/null
fi
hyprctl setcursor "$cursor" "$size" >/dev/null
gsettings set org.gnome.desktop.interface cursor-theme "$cursor" 2>/dev/null || true

# App icons: tint buuf-nestort toward the theme (~2s to build, cached per theme).
icon_src="$icons/buuf-nestort"
icon_theme="${theme^}-Icons"
icon_strength=0.85
read -r shadow accent_dark text_light < <(python3 - "$theme" <<'PY'
import importlib.util, os, sys
spec = importlib.util.spec_from_file_location("theme_apps", os.path.expanduser("~/.config/hypr/theme-apps.py"))
m = importlib.util.module_from_spec(spec); spec.loader.exec_module(m)
t = m.load_theme(sys.argv[1])
print(t.get("shadow", "#121212"), t.get("accentDark", t["accent"]), t.get("textLight", "#d0daed"))
PY
)
icon_stamp="$icon_src|$shadow|$accent_dark|$accent|$text_light|$icon_strength"
if [[ "$(cat "$icons/$icon_theme/.colors" 2>/dev/null)" != "$icon_stamp" ]]; then
    python3 "$icons/recolor_icons.py" "$icon_src" "$icons/$icon_theme" "$icon_theme" \
        "$shadow" "$accent_dark" "$accent" "$text_light" "$icon_strength"
    echo "$icon_stamp" > "$icons/$icon_theme/.colors"
    icons_rebuilt=1
fi
gsettings set org.gnome.desktop.interface icon-theme "$icon_theme" 2>/dev/null || true  # GTK apps update live
# Quickshell loads its icon theme (Themed-Icons, see shell.qml) only at startup,
# so restart it when the icons it would see have changed.
if [[ "$(readlink "$icons/Themed-Icons" 2>/dev/null)" != "$icon_theme" || -n "${icons_rebuilt:-}" ]]; then
    ln -sfn "$icon_theme" "$icons/Themed-Icons"
    if pgrep -f '/bin/quickshell( |$)' >/dev/null; then
        sleep 1  # let Quickshell finish saving settings.json
        pkill -f '/bin/quickshell( |$)' || true
        for _ in $(seq 50); do pgrep -f '/bin/quickshell( |$)' >/dev/null || break; sleep 0.1; done
        QML_IMPORT_PATH="$HOME/.nix-profile/lib/qt-6/qml" setsid -f qs >/dev/null 2>&1 </dev/null 9>&-  # 9>&-: don't hand our lock to qs
    fi
fi

# Lock screen + screensaver art (hyprlock slab, screensaver sprites/colors), ~5s, cached per theme.
lock_dir="$HOME/.config/hypr/lock"
lock_stamp="$theme|$base|$accent|$highlight|$(stat -c %Y "$lock_dir/make_lock.py" "$HOME/.config/hypr/wallpapers_bundled/fossil_bed.png" | tr '\n' ' ')"
if [[ "$(cat "$lock_dir/.stamp" 2>/dev/null)" != "$lock_stamp" ]]; then
    python3 "$lock_dir/make_lock.py" "$theme" && echo "$lock_stamp" > "$lock_dir/.stamp"
fi

# Remembered so hyprland.lua uses these at next login / reload.
printf 'cursor=%s\nactive_border=%s\ninactive_border=%s\n' "$cursor" "$active" "$inactive" > "$state"
