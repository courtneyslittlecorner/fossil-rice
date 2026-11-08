#!/usr/bin/env python3
"""Build the lock screen and screensaver art for a Quickshell theme.

Usage: make_lock.py THEME [--preview PREVIEW.png]

Writes:
  ~/.config/hypr/lock/lock_bg.png        hyprlock background: the fossil-bed rock, blurred, with a
                                         carved stone slab (frame, dividers, fossils) baked in
  ~/.config/hypr/lock/colors.conf        hyprlock $variables in the theme's colors
  ~/.config/quickshell-screensaver/      theme.json + sprites/ (living ammonites, trilobites, seafloor)

Called by theme-sync.sh when the theme changes. The slab layout matches the label positions in
~/.config/hypr/hyprlock.conf: keep the two in step (Y_* below are hyprlock offsets, up = positive).
"""
import importlib.util, json, math, os, random, subprocess, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter, ImageFont

HOME = os.path.expanduser("~")
HYPR = os.path.join(HOME, ".config/hypr")
OUT = os.path.join(HYPR, "lock")
SAVER = os.path.join(HOME, ".config/quickshell-screensaver")
WALL = os.path.join(HYPR, "wallpapers_bundled")


def load(name, path):
    spec = importlib.util.spec_from_file_location(name, path)
    m = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(m)
    return m


TA = load("theme_apps", os.path.join(HYPR, "theme-apps.py"))
FB = load("make_fossil_bed", os.path.join(WALL, "make_fossil_bed.py"))  # fossil_tile(); FB.F = add_fossils
F = FB.F

# Slab layout (hyprlock offsets from screen centre, up = positive)
TW, TH = 580, 770
Y_EMBLEM, Y_TIME, Y_DATE, Y_DIV, Y_HEAD, Y_WELCOME, Y_INPUT, Y_FLOURISH, Y_FOOT = 312, 190, 100, 58, 12, -30, -110, -190, -280
INPUT_W, INPUT_H = 360, 50


def hexrgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def mix(a, b, t):
    return tuple(round(x + (y - x) * t) for x, y in zip(a, b))


def scale(c, k):
    return tuple(max(0, min(255, round(v * k))) for v in c)


def screen_size():
    try:
        mons = json.loads(subprocess.run(["hyprctl", "monitors", "-j"], capture_output=True, text=True, timeout=3).stdout)
        m = max(mons, key=lambda m: m["width"] * m["height"])
        return round(m["width"] / m["scale"]), round(m["height"] / m["scale"])
    except Exception:
        return 1920, 1200


def cover(img, W, H):
    k = max(W / img.width, H / img.height)
    img = img.resize((math.ceil(img.width * k), math.ceil(img.height * k)), Image.LANCZOS)
    x, y = (img.width - W) // 2, (img.height - H) // 2
    return img.crop((x, y, x + W, y + H))


def diamond(d, cx, cy, r, fill):
    d.polygon([(cx, cy - r), (cx + r * 0.75, cy), (cx, cy + r), (cx - r * 0.75, cy)], fill=fill)


def carved_line(img, pts, color, width, light):
    """A groove: dark cut with a light lip just below-right, like letters chiselled in stone."""
    d = ImageDraw.Draw(img)
    d.line([(x + 1, y + 1) for x, y in pts], fill=light, width=width)
    d.line(pts, fill=color, width=width)


def divider(img, cx, cy, half, t, dark_lip):
    """The desktop's ───◆─── ornament, carved."""
    for sgn in (-1, 1):
        a, b = cx + sgn * 16, cx + sgn * half
        carved_line(img, [(a, cy), (b, cy)], t["accentDark"] + (255,), 2, dark_lip)
        diamond(ImageDraw.Draw(img), b + sgn * 6, cy, 4, t["accentDark"] + (255,))
    d = ImageDraw.Draw(img)
    diamond(d, cx + 1, cy + 1, 9, dark_lip)
    diamond(d, cx, cy, 9, t["accent"] + (255,))


def lock_background(t, W, H, rng):
    rock = Image.open(os.path.join(WALL, "fossil_bed.png")).convert("RGB")
    full = cover(rock, W, H)

    # Backdrop: the wallpaper rock, softened, dimmed and pulled toward the theme's shadow
    bg = full.filter(ImageFilter.GaussianBlur(5))
    bg = Image.blend(bg, Image.new("RGB", bg.size, t["shadow"]), 0.42)
    bg = bg.point(lambda v: round(v * 0.72))
    vig = Image.radial_gradient("L").resize((W, H)).point(lambda v: round(min(255, v * 1.15) * 0.75))
    bg = Image.composite(Image.new("RGB", bg.size, (6, 6, 5)), bg, vig).convert("RGBA")

    cx, cy = W // 2, H // 2
    x0, y0 = cx - TW // 2, cy - TH // 2
    box = (x0, y0, x0 + TW, y0 + TH)
    R = 14

    # Drop shadow
    sh = Image.new("L", (W, H), 0)
    ImageDraw.Draw(sh).rounded_rectangle((x0 + 4, y0 + 18, x0 + TW + 4, y0 + TH + 22), R, fill=200)
    shadow = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    shadow.putalpha(sh.filter(ImageFilter.GaussianBlur(22)))
    bg.alpha_composite(shadow)

    # The slab: a polished cut of the same rock, darkened toward the theme's base colour
    slab = full.crop(box).filter(ImageFilter.GaussianBlur(2.5))
    slab = Image.blend(slab, Image.new("RGB", slab.size, t["base"]), 0.74).point(lambda v: round(v * 0.9))
    glow = Image.radial_gradient("L").resize((TW, TH)).point(lambda v: 255 - v)
    lit = slab.point(lambda v: min(255, round(v * 1.18)))
    slab = Image.composite(lit, slab, glow.point(lambda v: round(v * 0.6))).convert("RGBA")
    sd = ImageDraw.Draw(slab)
    avg = tuple(round(v) for v in slab.convert("RGB").resize((1, 1), Image.BOX).getpixel((0, 0)))
    lip = scale(avg, 1.45) + (150,)
    groove = scale(avg, 0.45) + (255,)

    # Chiselled bevel: light top-left edge, dark bottom-right
    for i in range(5):
        a = 110 - i * 22
        sd.rounded_rectangle((i, i, TW - 1 - i, TH - 1 - i), R - i, outline=scale(avg, 1.6) + (a,), width=1)
    bev = Image.new("RGBA", (TW, TH), (0, 0, 0, 0))
    ImageDraw.Draw(bev).rounded_rectangle((0, 0, TW - 1, TH - 1), R, outline=(0, 0, 0, 170), width=5)
    bev.putalpha(ImageChops.multiply(bev.getchannel("A"), Image.linear_gradient("L").rotate(-45, expand=False).resize((TW, TH))))
    slab.alpha_composite(bev)

    # Engraved double frame, accent corner diamonds
    for inset, col, w in ((16, groove, 2), (23, t["accentDark"] + (255,), 1)):
        carved_line(slab, [(inset, inset), (TW - inset, inset), (TW - inset, TH - inset), (inset, TH - inset), (inset, inset)], col, w, lip)
    for px, py in ((16, 16), (TW - 16, 16), (16, TH - 16), (TW - 16, TH - 16)):
        diamond(sd, px + 1, py + 1, 7, lip)
        diamond(sd, px, py, 7, t["accent"] + (255,))

    to_y = lambda off: TH // 2 - off  # hyprlock offset -> slab pixel row

    # Fossils carved into the slab: an ammonite crest, trilobites + ammonite along the foot
    def carve(kind, size, rot, x, y):
        tile = FB.fossil_tile(kind, size, rot, avg, rng)
        slab.alpha_composite(tile, (round(x - tile.width / 2), round(y - tile.height / 2)))

    carve("ammonite", 42, 0.6, TW / 2, to_y(Y_EMBLEM))
    carve("trilobite", 74, -0.35, TW / 2 - 150, to_y(Y_FOOT))
    carve("ammonite", 30, 2.2, TW / 2, to_y(Y_FOOT) + 4)
    carve("trilobite", 74, 0.35, TW / 2 + 150, to_y(Y_FOOT))
    # tiny ammonites tucked in the upper corners, inside the frame
    carve("ammonite", 15, 4.0, 52, 54)
    carve("ammonite", 15, 1.1, TW - 52, 54)

    divider(slab, TW // 2, to_y(Y_DIV), 150, t, lip)
    divider(slab, TW // 2, to_y(Y_FLOURISH), 110, t, lip)

    # A groove for the password field (hyprlock draws the field itself inside it)
    gx0, gy0 = TW // 2 - INPUT_W // 2 - 7, to_y(Y_INPUT) - INPUT_H // 2 - 7
    gx1, gy1 = gx0 + INPUT_W + 14, gy0 + INPUT_H + 14
    sd.rounded_rectangle((gx0 + 1, gy0 + 1, gx1 + 1, gy1 + 1), 10, outline=lip, width=1)
    sd.rounded_rectangle((gx0, gy0, gx1, gy1), 10, fill=scale(avg, 0.6) + (200,), outline=groove, width=2)

    mask = Image.new("L", (TW, TH), 0)
    ImageDraw.Draw(mask).rounded_rectangle((0, 0, TW - 1, TH - 1), R, fill=255)
    slab.putalpha(ImageChops.multiply(slab.getchannel("A"), mask))
    bg.alpha_composite(slab, (x0, y0))
    return bg.convert("RGB")


def colors_conf(t):
    hx = lambda c: "%02x%02x%02x" % c
    lines = ["# Generated by ~/.config/hypr/lock/make_lock.py from the current Quickshell theme. Don't edit.",
             "# Sourced by ~/.config/hypr/hyprlock.conf."]
    for k in ("base", "shadow", "accent", "accentDark", "textLight", "danger", "warning", "highlight"):
        lines.append(f"$lock_{k} = rgb({hx(t[k])})")
    lines.append(f"$lock_field = rgba({hx(scale(t['shadow'], 0.9))}e6)")
    lines.append(f"$lock_textSoft = rgba({hx(t['textLight'])}c8)")
    return "\n".join(lines) + "\n"


# ── Screensaver art ─────────────────────────────────────────────────────────────

SHELLS = [  # (hi, lo, dark, ink, stripe) for the living ammonites
    ((240, 228, 198), (206, 178, 136), (164, 130, 92), (92, 62, 40), (120, 70, 40)),
    ((236, 214, 204), (200, 160, 146), (160, 116, 104), (90, 52, 46), (128, 64, 56)),
    ((222, 222, 208), (176, 176, 160), (130, 132, 118), (64, 66, 58), (86, 80, 66)),
]


def living_ammonite(R, palette, rng):
    """A living ammonite: the shell's real outline (the last whorl, open at the aperture), flame
    stripes, and the animal's hood, eye and tentacles coming out of the aperture to the right.
    Returns (sprite, shell centre x); the shell centre is at height/2."""
    hi, lo, dark, ink, stripe = palette
    S = 3
    Rs = R * S
    b = math.log(2) / (2 * math.pi)
    tmax = 3.2 * 2 * math.pi
    rot = -math.pi / 2 - tmax % (2 * math.pi)   # aperture straight up, opening to the right
    r = lambda th: Rs * math.exp(b * (th - tmax))
    W, H = int(Rs * 3.3), int(Rs * 2.2)
    cx, cy = Rs * 1.1, H / 2
    pt = lambda th, rr: (cx + rr * math.cos(th + rot), cy + rr * math.sin(th + rot))
    img = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    d = ImageDraw.Draw(img)

    # tentacles first (under the hood), streaming out of the aperture
    for i in range(10):
        f = i / 9
        ox, oy = cx + Rs * 0.05, cy - Rs * (0.56 + 0.4 * f)
        length = Rs * rng.uniform(0.8, 1.15) * (1 - abs(f - 0.5) * 0.5)
        curl = rng.uniform(-0.6, 0.6)
        spread = (f - 0.5) * 0.5
        pts = [(ox + length * u, oy + length * (spread * u + 0.12 * curl * math.sin(u * 3.4))) for u in (k / 30 for k in range(31))]
        col = mix((206, 140, 122), (156, 96, 86), (i % 3) / 2)
        for k in range(30):
            w = max(2, round(Rs / 10 * (1 - k / 32)))
            d.line([pts[k], pts[k + 1]], fill=col + (240,), width=w)
            if k % 6 == 3:  # suckers / bands
                d.ellipse([pts[k][0] - w * .25, pts[k][1] - w * .25, pts[k][0] + w * .25, pts[k][1] + w * .25], fill=mix(col, (250, 220, 200), .4) + (200,))

    # shell silhouette: outer edge of the last whorl, closed across the aperture
    outline = [pt(th, r(th)) for th in (tmax - 2 * math.pi + k * 2 * math.pi / 400 for k in range(401))]
    mask = Image.new("L", (W, H), 0)
    ImageDraw.Draw(mask).polygon(outline, fill=255)
    wash = F.radial_wash((W // 6, H // 6), cx / 6, cy / 6, Rs / 6, hi, lo).resize((W, H), Image.BILINEAR).convert("RGBA")
    wash.putalpha(mask)
    img.alpha_composite(wash)
    d = ImageDraw.Draw(img)
    # shade the inner side of each whorl
    shade = Image.new("L", (W, H), 0)
    sd = ImageDraw.Draw(shade)
    th = 2 * math.pi
    while th < tmax:
        p = pt(th, r(th) * 0.93)
        rad = (r(th) - r(th - 2 * math.pi)) * 0.16
        sd.ellipse([p[0] - rad, p[1] - rad, p[0] + rad, p[1] + rad], fill=110)
        th += 0.04
    shade = ImageChops.multiply(shade.filter(ImageFilter.GaussianBlur(Rs * 0.03)), mask)
    dk = Image.new("RGBA", (W, H), dark + (255,))
    dk.putalpha(shade)
    img.alpha_composite(dk)
    # flame stripes on the last whorl and a half
    stripes = Image.new("RGBA", (W, H), (0, 0, 0, 0))
    sdr = ImageDraw.Draw(stripes)
    th = tmax - 0.3
    while th > tmax - 2 * math.pi * 1.5:
        r1, r2 = r(th - 2 * math.pi), r(th)
        pts = [pt(th - 0.22 * u + 0.04 * math.sin(u * 7), r1 + (r2 - r1) * (0.12 + 0.82 * u)) for u in (k / 12 for k in range(13))]
        sdr.line(pts, fill=stripe + (110,), width=max(3, round((r2 - r1) * 0.16)), joint="curve")
        th -= 0.4
    stripes.putalpha(ImageChops.multiply(stripes.getchannel("A"), mask))
    img.alpha_composite(stripes)
    d = ImageDraw.Draw(img)
    # ribs, spiral suture and outline in ink
    wr = max(1, round(Rs / 48))
    th = 2 * math.pi + 0.35
    while th <= tmax:
        r1, r2 = r(th), r(th - 2 * math.pi)
        d.line(F.qbez(pt(th, r1), pt(th - 0.13, (r1 + r2) / 2), pt(th, r2)), fill=ink + (200,), width=wr, joint="curve")
        th += 0.17 + 5 / (R + 20)
    ws = max(2, round(Rs / 26))
    d.line([pt(th, r(th)) for th in (0.8 + k * 0.03 for k in range(int((tmax - 2 * math.pi - 0.8) / 0.03)))], fill=ink + (220,), width=ws, joint="curve")
    d.line(outline + [outline[0]], fill=ink + (235,), width=ws + 1, joint="curve")

    # hood over the top of the aperture, and the eye beside it
    hx0, hy = cx - Rs * 0.04, cy - Rs * 0.86
    d.chord([hx0 - Rs * 0.06, hy - Rs * 0.2, hx0 + Rs * 0.42, hy + Rs * 0.2], 180, 360, fill=mix(stripe, (50, 34, 26), 0.35) + (250,))
    d.chord([hx0 - Rs * 0.06, hy - Rs * 0.2, hx0 + Rs * 0.42, hy + Rs * 0.2], 0, 180, fill=mix(stripe, (50, 34, 26), 0.35) + (250,))
    ex, ey, er = cx + Rs * 0.2, cy - Rs * 0.62, Rs * 0.075
    d.ellipse([ex - er * 1.3, ey - er * 1.3, ex + er * 1.3, ey + er * 1.3], fill=(214, 168, 146, 255))
    d.ellipse([ex - er, ey - er, ex + er, ey + er], fill=(22, 18, 16, 255))
    d.ellipse([ex - er * 0.15, ey - er * 0.7, ex + er * 0.4, ey - er * 0.15], fill=(245, 240, 228, 235))
    return img.resize((W // S, H // S), Image.LANCZOS), cx / S


def living_trilobite(L, phase):
    """Trilobite facing up, with little legs peeking out at the sides (phase 0/1 for walking)."""
    F.WASH_HI, F.WASH_LO, F.WASH_DARK, F.INK, F.WASH_A = (214, 200, 176), (164, 146, 120), (120, 104, 84), (56, 44, 32), 255
    body = F.trilobite(L, 0)
    out = Image.new("RGBA", body.size, (0, 0, 0, 0))
    d = ImageDraw.Draw(out)
    c = body.width / 2
    P = lambda x, y: (c + x * L, c + y * L)
    for i in range(10):
        y = -.08 + i * .046
        hw = .255 - .06 * i / 9
        swing = (.025 if (i + phase) % 2 else -.025)
        for sgn in (-1, 1):
            d.line([P(sgn * (hw - .03), y), P(sgn * (hw + .06), y + swing + .01)], fill=(120, 74, 56, 230), width=max(2, round(L / 45)))
    # antennae
    for sgn in (-1, 1):
        d.line(F.qbez(P(sgn * .05, -.48), P(sgn * (.12 + phase * .02), -.62), P(sgn * (.22 + phase * .02), -.6)), fill=(110, 70, 52, 230), width=max(1, round(L / 60)))
    out.alpha_composite(body)
    return out


def seafloor(W, t, rng):
    """A strip of the fossil-bed rock with a ragged top edge, shaded for deep water."""
    Hs = 300
    rock = cover(Image.open(os.path.join(WALL, "fossil_bed.png")).convert("RGB"), W, round(W * 2160 / 3840))
    strip = rock.crop((0, rock.height - Hs, W, rock.height))
    deep = mix(t["shadow"], (10, 30, 34), 0.5)
    strip = Image.blend(strip, Image.new("RGB", strip.size, deep), 0.5)
    shade = Image.linear_gradient("L").resize((W, Hs)).point(lambda v: round(v * 0.55))
    strip = Image.composite(Image.new("RGB", strip.size, (4, 8, 9)), strip, shade).convert("RGBA")
    # ragged top: low hills + pebbly noise
    alpha = Image.new("L", (W, Hs), 0)
    d = ImageDraw.Draw(alpha)
    ph = [rng.uniform(0, 6.3) for _ in range(4)]
    top = []
    for x in range(0, W + 8, 8):
        y = 120 + 34 * math.sin(x / 310 + ph[0]) + 18 * math.sin(x / 113 + ph[1]) + 7 * math.sin(x / 37 + ph[2]) + rng.uniform(-3, 3)
        top.append((x, y))
    d.polygon(top + [(W, Hs), (0, Hs)], fill=255)
    alpha = alpha.filter(ImageFilter.GaussianBlur(1.5))
    strip.putalpha(alpha)
    # light from above catching the crest
    rim = Image.new("RGBA", (W, Hs), mix(t["accent"], (180, 220, 210), 0.5) + (0,))
    ra = ImageChops.subtract(alpha, ImageChops.offset(alpha, 0, 5)).filter(ImageFilter.GaussianBlur(2)).point(lambda v: round(v * 0.45))
    rim.putalpha(ra)
    strip.alpha_composite(rim)
    return strip, [(x, y) for x, y in top]


def screensaver_assets(t, W, H, rng):
    sp = os.path.join(SAVER, "sprites")
    os.makedirs(sp, exist_ok=True)
    meta = {"ammonites": [], "trilobite": {}}
    for i, pal in enumerate(SHELLS):
        img, scx = living_ammonite(110, pal, rng)
        img.save(os.path.join(sp, f"ammonite{i}.png"))
        meta["ammonites"].append({"src": f"sprites/ammonite{i}.png", "w": img.width, "h": img.height, "shellX": scx})
    for ph in (0, 1):
        tri = living_trilobite(120, ph)
        tri.save(os.path.join(sp, f"trilobite{ph}.png"))
    meta["trilobite"] = {"w": tri.width, "h": tri.height}
    floor, top = seafloor(W, t, rng)
    floor.save(os.path.join(sp, "seafloor.png"))
    meta["floor"] = {"h": floor.height, "top": [round(y) for _, y in top[::4]], "step": 32}

    water = lambda k, base: "#%02x%02x%02x" % mix(base, t["shadow"], k)
    teal = mix(t["accent"], (40, 96, 104), 0.62)
    hx = lambda c: "#%02x%02x%02x" % c
    meta["colors"] = {
        "waterTop": hx(scale(teal, 0.62)), "waterMid": hx(scale(mix(teal, t["shadow"], 0.55), 0.5)),
        "waterBottom": hx(scale(t["shadow"], 0.6)), "accent": hx(t["accent"]), "accentDark": hx(t["accentDark"]),
        "textLight": hx(t["textLight"]), "ray": hx(mix(t["accent"], (220, 240, 230), 0.6)),
        "snow": hx(mix(t["textLight"], t["accent"], 0.3)),
    }
    with open(os.path.join(SAVER, "theme.json.tmp"), "w") as fh:
        json.dump(meta, fh, indent=1)
    os.replace(os.path.join(SAVER, "theme.json.tmp"), os.path.join(SAVER, "theme.json"))


def preview(bg, t, path):
    """Approximate what hyprlock draws on top, to check the layout."""
    img = bg.copy()
    d = ImageDraw.Draw(img)
    fdir = os.path.join(HOME, ".local/share/fonts/linux-antiquity")
    W, H = img.size
    cx, cy = W // 2, H // 2

    def text(s, off, font, size, col):
        f = ImageFont.truetype(os.path.join(fdir, font), size)
        d.text((cx, cy - off), s, font=f, fill=col, anchor="mm")
    text("14:07", Y_TIME, "Boska-Variable.ttf", 104, t["accent"])
    text("Sunday · 8 November 2026", Y_DATE, "Recia-Variable.ttf", 19, t["textLight"])
    text("Sealed in Stone", Y_HEAD, "Boska-Variable.ttf", 32, t["accent"])
    text("welcome back, courtney", Y_WELCOME, "Recia-VariableItalic.ttf", 16, t["textLight"])
    d.rounded_rectangle((cx - INPUT_W // 2, cy + 110 - INPUT_H // 2, cx + INPUT_W // 2, cy + 110 + INPUT_H // 2), 6,
                        fill=scale(t["shadow"], 0.9), outline=t["accentDark"])
    text("speak the word of passage…", Y_INPUT, "Recia-VariableItalic.ttf", 15, t["accentDark"])
    img.save(path)


def main():
    if len(sys.argv) < 2:
        sys.exit(__doc__)
    t = {k: hexrgb(v) for k, v in TA.load_theme(sys.argv[1]).items()}
    t.setdefault("shadow", scale(t["base"], 0.6))
    t.setdefault("accentDark", scale(t["accent"], 0.7))
    W, H = screen_size()
    rng = random.Random(1908)
    os.makedirs(OUT, exist_ok=True)
    bg = lock_background(t, W, H, rng)
    bg.save(os.path.join(OUT, "lock_bg.png.tmp.png"))
    os.replace(os.path.join(OUT, "lock_bg.png.tmp.png"), os.path.join(OUT, "lock_bg.png"))
    with open(os.path.join(OUT, "colors.conf"), "w") as fh:
        fh.write(colors_conf(t))
    screensaver_assets(t, W, H, random.Random(77))
    if "--preview" in sys.argv:
        preview(bg, t, sys.argv[sys.argv.index("--preview") + 1])


if __name__ == "__main__":
    main()
