#!/usr/bin/env python3
"""Build a theme-tinted copy of a PNG icon theme (e.g. buuf-nestort).

Each icon is gradient-mapped by brightness onto the theme's colors
(shadow -> accentDark -> accent -> textLight), then blended with the original
at STRENGTH so the painted shading and some original color survive.
Symlinks are copied as-is (they're relative), so aliases keep working.

Usage: recolor_icons.py SRC_THEME_DIR DEST_THEME_DIR NAME SHADOW ACCENT_DARK ACCENT TEXT_LIGHT [STRENGTH]
Called by ~/.config/hypr/theme-sync.sh when the Quickshell theme changes.
"""
import os, shutil, subprocess, sys
from multiprocessing import Pool
from PIL import Image

SKIP_EXT = (".sh", ".md", ".cache", ".gitignore")
LUT = None
STRENGTH = 0.85


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def make_lut(stops):
    """256-step gradient through the stops, laid out as PIL point() wants (R..., G..., B...)."""
    out = []
    for c in range(3):
        for i in range(256):
            t = i / 255 * (len(stops) - 1)
            k = min(int(t), len(stops) - 2)
            f = t - k
            out.append(round(stops[k][c] + (stops[k + 1][c] - stops[k][c]) * f))
    return out


def init(lut, strength):
    global LUT, STRENGTH
    LUT, STRENGTH = lut, strength


def recolor(job):
    src, dst = job
    try:
        im = Image.open(src)
        im.load()
        im = im.convert("RGBA")
        alpha = im.getchannel("A")
        rgb = im.convert("RGB")
        mapped = rgb.convert("L").convert("RGB").point(LUT)
        out = Image.blend(rgb, mapped, STRENGTH)
        out.putalpha(alpha)
        out.save(dst, optimize=False)
    except Exception as e:  # corrupt/odd file: keep the original rather than fail the build
        print(f"recolor_icons: copying {src} unchanged ({e})", file=sys.stderr)
        shutil.copy2(src, dst)


def main():
    src, dest, name, *colors = sys.argv[1:]
    strength = float(colors[4]) if len(colors) > 4 else STRENGTH
    lut = make_lut([hex_rgb(c) for c in colors[:4]])

    tmp = dest + ".building"
    shutil.rmtree(tmp, ignore_errors=True)
    jobs = []
    for root, dirs, files in os.walk(src):
        rel = os.path.relpath(root, src)
        dirs[:] = [d for d in dirs if not d.startswith(".")]
        os.makedirs(os.path.join(tmp, rel), exist_ok=True)
        for d in list(dirs):  # symlinked directories: copy the link, don't descend
            p = os.path.join(root, d)
            if os.path.islink(p):
                os.symlink(os.readlink(p), os.path.join(tmp, rel, d))
                dirs.remove(d)
        for f in files:
            s, d = os.path.join(root, f), os.path.join(tmp, rel, f)
            if os.path.islink(s):
                os.symlink(os.readlink(s), d)
            elif f == "index.theme":
                with open(s) as fh:
                    text = fh.read()
                lines = [f"Name={name}" if l.startswith("Name=") else l for l in text.splitlines()]
                with open(d, "w") as fh:
                    fh.write("\n".join(lines) + "\n")
            elif f.lower().endswith(".png"):
                jobs.append((s, d))
            elif not f.endswith(SKIP_EXT):
                shutil.copy2(s, d)

    with Pool(initializer=init, initargs=(lut, strength)) as pool:
        pool.map(recolor, jobs, chunksize=32)

    subprocess.run(["gtk-update-icon-cache", "-q", "-f", "-t", tmp], check=False)
    old = dest + ".old"
    shutil.rmtree(old, ignore_errors=True)
    if os.path.isdir(dest):
        os.rename(dest, old)
    os.rename(tmp, dest)
    shutil.rmtree(old, ignore_errors=True)
    print(f"recolor_icons: built {dest} ({len(jobs)} icons)")


if __name__ == "__main__":
    main()
