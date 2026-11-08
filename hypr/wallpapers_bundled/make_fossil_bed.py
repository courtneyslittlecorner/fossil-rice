#!/usr/bin/env python3
"""Paint a 3840x2160 wallpaper of layered sedimentary rock with ammonite and trilobite
fossils weathering out of it. Reuses the fossil drawings from add_fossils.py.

Usage: make_fossil_bed.py DEST.png [--seed S] [--fossils N] [--preview PREVIEW.png]
"""
import importlib.util, math, os, random, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
spec = importlib.util.spec_from_file_location("add_fossils", os.path.join(HERE, "add_fossils.py"))
F = importlib.util.module_from_spec(spec)
spec.loader.exec_module(F)

W, H = 3840, 2160
w, h = W // 2, H // 2     # the rock's structure is painted at half size, detail at full size

# Sediment colours: shales, mudstones, sandstones, a pale limestone and an ochre sand,
# nudged a little toward the desktop's sage theme.
ROCKS = [(70, 68, 60), (98, 90, 76), (132, 116, 92), (150, 142, 122), (54, 52, 46),
         (138, 110, 76), (110, 104, 88), (84, 80, 70)]
THEME = (120, 136, 104)


def tint(c, k=0.12):
    return tuple(round(a + (b - a) * k) for a, b in zip(c, THEME))


def noise(rng, cells, sigma=70):
    """Smooth value noise: a small random image blown up with bicubic smoothing."""
    n = Image.effect_noise(cells, sigma).filter(ImageFilter.GaussianBlur(0.6))
    return n.resize((w, h), Image.BICUBIC)


def strata(rng):
    # Band table along a warped depth axis
    bands, y = [], -200
    while y < h + 400:
        t = rng.choice([18, 26, 40, 60, 90, 130]) * rng.uniform(0.7, 1.3)
        kind = rng.random()
        bands.append((y, y + t, tint(rng.choice(ROCKS)), "pebbles" if kind < 0.16 else "plain"))
        y += t
    depth = []
    for (a, b, col, k) in bands:
        depth += [(col, k)] * int(round(b - a))
    big, mid, fine = noise(rng, (14, 8)), noise(rng, (60, 34)), noise(rng, (300, 170), 90)
    bp, mp, fp = big.load(), mid.load(), fine.load()
    img = Image.new("RGB", (w, h))
    px = img.load()
    tiltA, tiltB = rng.uniform(-0.06, 0.06), rng.uniform(0, 6.28)
    peb_rows = set()
    for yy in range(h):
        for xx in range(w):
            b = (bp[xx, yy] - 128) / 128
            m = (mp[xx, yy] - 128) / 128
            # warped, gently folded layers
            yw = yy + 70 * b + 12 * m + 40 * math.sin(xx * 0.0016 + tiltB) + tiltA * xx
            i = int(yw) + 200
            col, kind = depth[max(0, min(len(depth) - 1, i))]
            # soft mottling within each bed, and a hint of lamination
            k = 0.8 + 0.3 * (fp[xx, yy] / 255) + 0.08 * m + 0.05 * math.sin(yw * 0.9)
            px[xx, yy] = (min(255, int(col[0] * k)), min(255, int(col[1] * k)), min(255, int(col[2] * k)))
            if kind == "pebbles" and (xx % 23 == 0) and (yy % 19 == 0):
                peb_rows.add((xx, yy))
    return img, peb_rows


def pebbles(img, spots, rng):
    d = ImageDraw.Draw(img, "RGBA")
    for (x, y) in spots:
        if rng.random() < 0.45:
            continue
        x, y = x * 2 + rng.uniform(-20, 20), y * 2 + rng.uniform(-20, 20)
        rx, ry = rng.uniform(6, 22), rng.uniform(5, 15)
        base = tint(rng.choice([(150, 140, 120), (120, 112, 96), (176, 160, 130), (96, 92, 84)]))
        d.ellipse([x - rx + 3, y - ry + 4, x + rx + 3, y + ry + 4], fill=(20, 16, 10, 90))   # shadow
        d.ellipse([x - rx, y - ry, x + rx, y + ry], fill=base + (255,))
        d.ellipse([x - rx * 0.6, y - ry * 0.75, x + rx * 0.1, y - ry * 0.05], fill=(255, 245, 225, 45))


def cracks(img, rng, n=26):
    d = ImageDraw.Draw(img, "RGBA")
    for _ in range(n):
        x, y = rng.uniform(0, W), rng.uniform(0, H)
        ang = rng.uniform(0, 6.28)
        pts = [(x, y)]
        for _ in range(rng.randint(8, 30)):
            ang += rng.uniform(-0.5, 0.5)
            x += math.cos(ang) * rng.uniform(10, 34)
            y += math.sin(ang) * rng.uniform(10, 34)
            pts.append((x, y))
        d.line([(p[0] + 1.5, p[1] + 1.5) for p in pts], fill=(210, 196, 170, 40), width=2)
        d.line(pts, fill=(18, 14, 10, 150), width=2)


def fossil_tile(kind, size, rot, rock, rng):
    """A fossil carved into the rock: mineral-filled shell, light edges below-right, dark grooves.
    rock: the average colour around it, so each fossil takes on the bed it lies in."""
    mix = lambda a, b, t: tuple(round(x + (y - x) * t) for x, y in zip(a, b))
    lift = lambda c, k: tuple(min(255, round(v * k)) for v in c)
    shell = mix(lift(rock, 1.55), rng.choice([(222, 204, 168), (200, 196, 184), (214, 180, 120)]), rng.uniform(0.3, 0.55))
    F.INK = lift(rock, 0.38)
    F.WASH_HI, F.WASH_LO, F.WASH_DARK, F.WASH_A = lift(shell, 1.08), lift(shell, 0.85), lift(shell, 0.68), 225
    dark = F.ammonite(size, rot) if kind == "ammonite" else F.trilobite(size, rot)
    F.INK = (236, 222, 192)
    light = F.ammonite(size, rot, True) if kind == "ammonite" else F.trilobite(size, rot, True)
    # the ghost pass draws faintly; boost it into a crisp highlight
    light.putalpha(light.getchannel("A").point(lambda a: min(255, a * 3)))
    out = Image.new("RGBA", (dark.width + 8, dark.height + 8), (0, 0, 0, 0))
    # the hollow the fossil sits in: a soft dark ring in the rock
    hollow = Image.new("RGBA", out.size, (16, 12, 8, 0))
    hollow.putalpha(ImageChops.offset(dark.getchannel("A").resize(out.size), 0, 0).filter(ImageFilter.MaxFilter(5)).filter(ImageFilter.GaussianBlur(4)).point(lambda a: a * 0.55))
    out.alpha_composite(hollow, (0, 0))
    out.alpha_composite(light, (6, 6))
    out.alpha_composite(dark, (4, 4))
    # Weathering: on most fossils, part of the shell is still buried and fades into the rock.
    if rng.random() < 0.7:
        n = Image.effect_noise((6, 6), 90).resize(out.size, Image.BICUBIC)
        side = Image.linear_gradient("L").rotate(rng.uniform(0, 360)).resize(out.size)
        keep = ImageChops.add(n, side, scale=2.0).point(lambda v: max(0, min(255, (v - 40) * 3)))
        out.putalpha(ImageChops.multiply(out.getchannel("A"), keep))
    return out


def main():
    args = sys.argv[1:]
    opt = lambda k, dflt: (args.pop(args.index(k) + 1), args.remove(k))[0] if k in args else dflt
    seed = int(opt("--seed", 1107))
    nfossils = int(opt("--fossils", 28))
    preview = opt("--preview", None)
    dest = args[0]
    rng = random.Random(seed)
    random.seed(seed)

    base, peb = strata(rng)
    img = base.resize((W, H), Image.BICUBIC)
    # fine sandy grain over everything
    grain = Image.effect_noise((W, H), 28).convert("RGB")
    img = Image.blend(img, ImageChops.overlay(img, grain), 0.75)
    speck = Image.effect_noise((W // 3, H // 3), 60).resize((W, H), Image.NEAREST).convert("RGB")
    img = Image.blend(img, ImageChops.soft_light(img, speck), 0.6)
    pebbles(img, peb, rng)
    cracks(img, rng)
    img = img.convert("RGBA")

    # Fossils, spread out without overlapping; the screen crops the sides ("cover" on 16:10).
    cropx = (W * max(1920 / W, 1200 / H) - 1920) / 2 / max(1920 / W, 1200 / H)
    placed = []
    for i in range(nfossils):
        kind = "trilobite" if i % 2 else "ammonite"
        for _ in range(400):
            size = rng.uniform(55, 185) if kind == "ammonite" else rng.uniform(150, 400)
            r = size if kind == "ammonite" else size * 0.45
            x = rng.uniform(cropx + r, W - cropx - r)
            y = rng.uniform(r, H - r)
            if all(math.hypot(x - px, y - py) > r + pr + 40 for px, py, pr in placed):
                break
        else:
            continue
        placed.append((x, y, r))
        bx = (int(max(0, x - r)), int(max(0, y - r)), int(min(W, x + r)), int(min(H, y + r)))
        rock = img.crop(bx).convert("RGB").resize((1, 1), Image.BOX).getpixel((0, 0))
        t = fossil_tile(kind, size, rng.uniform(0, 6.28), rock, rng)
        img.alpha_composite(t, (int(x - t.width / 2), int(y - t.height / 2)))

    # soft vignette so the widgets sit on slightly darker rock at the edges
    vig = Image.new("L", (W // 8, H // 8), 0)
    ImageDraw.Draw(vig).ellipse([-W // 40, -H // 40, W // 8 + W // 40, H // 8 + H // 40], fill=255)
    vig = vig.filter(ImageFilter.GaussianBlur(40)).resize((W, H), Image.BICUBIC)
    shade = Image.new("RGBA", (W, H), (10, 8, 6, 255))
    shade.putalpha(vig.point(lambda v: int((255 - v) * 0.55)))
    img.alpha_composite(shade)

    img.convert("RGB").save(dest)
    if preview:
        img.convert("RGB").resize((W // 3, H // 3), Image.LANCZOS).save(preview)


if __name__ == "__main__":
    main()
