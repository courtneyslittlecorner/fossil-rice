#!/usr/bin/env python3
"""Draw ammonites and trilobites onto a wallpaper in the print's own pen-and-ink style
(olive ink linework over a pale sage wash), placed in its quietest areas.

Usage: add_fossils.py SRC.png DEST.png [--count N] [--seed S] [--preview PREVIEW.png]
"""
import math, random, sys
from PIL import Image, ImageChops, ImageDraw, ImageFilter

SS = 2  # supersample factor for each fossil tile

INK = (60, 78, 56)
WASH_HI = (226, 228, 198)
WASH_LO = (186, 198, 160)
WASH_DARK = (150, 168, 128)
WASH_A = 150   # wash opacity: lets the paper show through like the print's watercolour


def qbez(p0, p1, p2, n=12):
    return [((1 - t) ** 2 * p0[0] + 2 * (1 - t) * t * p1[0] + t * t * p2[0],
             (1 - t) ** 2 * p0[1] + 2 * (1 - t) * t * p1[1] + t * t * p2[1]) for t in (i / n for i in range(n + 1))]


def cbez(p0, p1, p2, p3, n=16):
    out = []
    for i in range(n + 1):
        t = i / n
        a, b, c, d = (1 - t) ** 3, 3 * (1 - t) ** 2 * t, 3 * (1 - t) * t * t, t ** 3
        out.append((a * p0[0] + b * p1[0] + c * p2[0] + d * p3[0], a * p0[1] + b * p1[1] + c * p2[1] + d * p3[1]))
    return out


def radial_wash(size, cx, cy, r, hi, lo):
    """A soft cream-to-sage wash, lighter toward the upper left like the print's flowers."""
    w = Image.new("RGB", size, lo)
    px = w.load()
    for y in range(size[1]):
        for x in range(size[0]):
            d = math.hypot(x - (cx - r * 0.3), y - (cy - r * 0.3)) / (r * 1.5)
            t = max(0.0, min(1.0, d))
            px[x, y] = tuple(round(h + (l - h) * t) for h, l in zip(hi, lo))
    return w


def ammonite(R, rot, ghost=False):
    """Returns an RGBA tile (at 1x) with the ammonite centred."""
    Rs = R * SS
    size = int(Rs * 2.3)
    c = size / 2
    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).ellipse([c - Rs, c - Rs, c + Rs, c + Rs], fill=WASH_A)
    wash = radial_wash((size, size), c, c, Rs, WASH_HI, WASH_LO).convert("RGBA")
    wash.putalpha(mask)
    tile.alpha_composite(wash)
    d = ImageDraw.Draw(tile)
    b = math.log(2) / (2 * math.pi)
    tmax = 3.2 * 2 * math.pi
    r = lambda th: Rs * math.exp(b * (th - tmax))
    pt = lambda th, rr: (c + rr * math.cos(th + rot), c + rr * math.sin(th + rot))
    # shade the inner side of each whorl (a darker wash just outside the spiral line)
    shade = Image.new("L", (size, size), 0)
    sd = ImageDraw.Draw(shade)
    for th in [x * 0.05 for x in range(int(2 * math.pi / 0.05), int(tmax / 0.05))]:
        p = pt(th, r(th) * 0.93)
        rad = (r(th) - r(th - 2 * math.pi)) * 0.16
        sd.ellipse([p[0] - rad, p[1] - rad, p[0] + rad, p[1] + rad], fill=90)
    shade = shade.filter(ImageFilter.GaussianBlur(Rs * 0.03))
    dark = Image.new("RGBA", (size, size), WASH_DARK + (255,))
    dark.putalpha(ImageChops.multiply(shade, mask.point(lambda a: 255 if a else 0)))
    tile.alpha_composite(dark)

    if ghost:
        tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        d = ImageDraw.Draw(tile)
    ink = INK + ((62,) if ghost else (205,))
    wr = max(1, round(Rs / 48))
    th = 2 * math.pi + 0.35
    while th <= tmax:
        r1, r2 = r(th), r(th - 2 * math.pi)
        p1, p2, pm = pt(th, r1), pt(th, r2), pt(th - 0.13, (r1 + r2) / 2)
        d.line(qbez(p1, pm, p2), fill=ink, width=wr, joint="curve")
        th += 0.17 + 5 / (R + 20)
    spiral = []
    th = 0.8
    while th <= tmax:
        spiral.append(pt(th, r(th)))
        th += 0.03
    ws = max(2, round(Rs / 26))
    d.line(spiral, fill=ink, width=ws, joint="curve")
    d.ellipse([c - Rs, c - Rs, c + Rs, c + Rs], outline=ink, width=ws + 1)
    return tile.resize((size // SS, size // SS), Image.LANCZOS)


def trilobite(L, rot, ghost=False):
    Ls = L * SS
    size = int(Ls * 1.25)
    c = size / 2
    P = lambda x, y: (c + x * Ls, c + y * Ls)
    out = []
    out += cbez(P(0, -.5), P(.24, -.5), P(.36, -.38), P(.34, -.22))
    out += cbez(P(.34, -.22), P(.37, -.08), P(.36, .04), P(.32, .16))      # genal spine
    out += [P(.26, -.13)]
    out += cbez(P(.26, -.15), P(.25, .08), P(.21, .28), P(.15, .36))
    out += cbez(P(.15, .36), P(.1, .47), P(-.1, .47), P(-.15, .36))
    out += cbez(P(-.15, .36), P(-.21, .28), P(-.25, .08), P(-.26, -.15))
    out += [P(-.26, -.13), P(-.32, .16)]
    out += cbez(P(-.32, .16), P(-.36, .04), P(-.37, -.08), P(-.34, -.22))
    out += cbez(P(-.34, -.22), P(-.36, -.38), P(-.24, -.5), P(0, -.5))

    tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    mask = Image.new("L", (size, size), 0)
    ImageDraw.Draw(mask).polygon(out, fill=WASH_A)
    wash = radial_wash((size, size), c, c - Ls * 0.1, Ls * 0.45, WASH_HI, WASH_LO).convert("RGBA")
    wash.putalpha(mask)
    tile.alpha_composite(wash)
    # the raised central (axial) lobe takes a deeper wash
    axial = Image.new("L", (size, size), 0)
    ad = ImageDraw.Draw(axial)
    ad.polygon(qbez(P(.075, -.15), P(.07, .15), P(.035, .42)) + qbez(P(-.035, .42), P(-.07, .15), P(-.075, -.15)), fill=110)
    ad.polygon(cbez(P(.075, -.2), P(.11, -.34), P(.08, -.45), P(0, -.45)) + cbez(P(0, -.45), P(-.08, -.45), P(-.11, -.34), P(-.075, -.2)), fill=80)
    dark = Image.new("RGBA", (size, size), WASH_DARK + (255,))
    dark.putalpha(axial.filter(ImageFilter.GaussianBlur(Ls * 0.012)))
    tile.alpha_composite(dark)

    if ghost:
        tile = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    d = ImageDraw.Draw(tile)
    ink = INK + ((66,) if ghost else (210,))
    w = max(2, round(Ls / 70))
    d.line(out + [out[0]], fill=ink, width=w + 1, joint="curve")
    lines = [
        qbez(P(-.31, -.17), P(0, -.165), P(.31, -.17)),
        cbez(P(.075, -.2), P(.11, -.34), P(.08, -.45), P(0, -.45)) + cbez(P(0, -.45), P(-.08, -.45), P(-.11, -.34), P(-.075, -.2)),
        qbez(P(.14, -.36), P(.21, -.32), P(.15, -.26)),
        qbez(P(-.14, -.36), P(-.21, -.32), P(-.15, -.26)),
        [P(.085, -.37), P(.04, -.35)], [P(-.085, -.37), P(-.04, -.35)],
        [P(.095, -.3), P(.045, -.28)], [P(-.095, -.3), P(-.045, -.28)],
        qbez(P(.075, -.15), P(.07, .15), P(.035, .42)),
        qbez(P(-.075, -.15), P(-.07, .15), P(-.035, .42)),
    ]
    for ln in lines:
        d.line(ln, fill=ink, width=w, joint="curve")
    for i in range(10):
        y, t = -.1 + i * .046, i / 9
        hw = .255 - .06 * t
        seg = qbez(P(-hw, y + .035), P(-hw * .55, y - .005), P(-.07, y)) + qbez(P(-.07, y), P(0, y + .012), P(.07, y)) + qbez(P(.07, y), P(hw * .55, y - .005), P(hw, y + .035))
        d.line(seg, fill=ink, width=max(1, w - 1), joint="curve")
    for i in range(2):
        y = .37 + i * .035
        d.line(qbez(P(-.11 + i * .03, y - .01), P(0, y + .03), P(.11 - i * .03, y - .01)), fill=ink, width=max(1, w - 1))
    tile = tile.rotate(-math.degrees(rot), resample=Image.BICUBIC, expand=True)
    return tile.resize((tile.width // SS, tile.height // SS), Image.LANCZOS)


def busyness(img):
    """Edge-density map at 1/8 scale: low values = quiet areas of the print."""
    small = img.convert("L").resize((img.width // 8, img.height // 8), Image.BILINEAR)
    e = small.filter(ImageFilter.FIND_EDGES).point(lambda v: min(255, v * 3))
    return e.filter(ImageFilter.GaussianBlur(4)), small


def main():
    args = sys.argv[1:]
    opt = lambda k, dflt: (args.pop(args.index(k) + 1), args.remove(k))[0] if k in args else dflt
    count = int(opt("--count", 16))
    seed = int(opt("--seed", 7))
    preview = opt("--preview", None)
    src, dest = args
    rng = random.Random(seed)
    img = Image.open(src).convert("RGBA")
    W, H = img.size
    busy, _ = busyness(img)
    bp = busy.load()
    bw, bh = busy.size

    # Screen 1920x1200 shows the 16:9 image with "cover": the sides are cropped off.
    s = max(1920 / W, 1200 / H)
    cropx = (W * s - 1920) / 2 / s
    # Spots the desktop widgets leave visible (screen px), so some fossils are always seen.
    open_spots = [(250, 700), (300, 960), (180, 560), (1300, 1000), (1000, 1010), (1840, 1000), (1840, 330)]
    want = [((sx / s) + cropx, sy / s) for sx, sy in open_spots]

    def score(x, y, r):
        tot, n = 0, 0
        R = max(2, int(r / 8))
        cx, cy = int(x / 8), int(y / 8)
        for yy in range(cy - R, cy + R + 1, 2):
            for xx in range(cx - R, cx + R + 1, 2):
                if 0 <= xx < bw and 0 <= yy < bh:
                    tot += bp[xx, yy]
                    n += 1
        return tot / max(1, n)

    # Hand-picked plain-paper spots (in 1280x720 preview coordinates of the print).
    spots = [("trilobite", 565, 100, 320, 0.5), ("trilobite", 968, 118, 300, -1.9), ("ammonite", 1012, 368, 140, 0),
             ("trilobite", 845, 528, 330, 1.9), ("ammonite", 612, 532, 130, 0), ("ammonite", 245, 352, 120, 0),
             ("trilobite", 262, 632, 270, 0.35), ("ammonite", 640, 58, 85, 0)]
    # Big faint "watermark" fossils behind everything, free to overlap the artwork.
    ghosts = [("ammonite", 410, 150, 300, 0), ("trilobite", 780, 300, 720, 2.6), ("ammonite", 1150, 520, 260, 0),
              ("trilobite", 130, 470, 520, 0.2), ("ammonite", 420, 520, 230, 0), ("ammonite", 880, 640, 210, 0),
              ("trilobite", 1150, 160, 520, -2.2), ("ammonite", 690, 330, 240, 0), ("trilobite", 1000, 300, 430, 1.1),
              ("ammonite", 120, 130, 200, 0), ("trilobite", 520, 660, 440, -1.4)]
    kinds = [(k, x * W / 1280, y * H / 720, sz, rt) for k, x, y, sz, rt in spots]
    for kind, x, y, size, rt in ghosts:
        x, y = x * W / 1280, y * H / 720
        tile = ammonite(size, rng.uniform(0, 6.28), True) if kind == "ammonite" else trilobite(size, rt, True)
        img.alpha_composite(tile, (int(x - tile.width / 2), int(y - tile.height / 2)))
    for kind, x, y, size, rt in kinds:
        tile = ammonite(size, rng.uniform(0, 6.28)) if kind == "ammonite" else trilobite(size, rt)
        # a faint shadow so they sit on the paper like the print's beetle
        sh = Image.new("RGBA", tile.size, (60, 70, 50, 0))
        sh.putalpha(tile.getchannel("A").point(lambda a: a * 0.22).filter(ImageFilter.GaussianBlur(5)))
        img.alpha_composite(sh, (int(x - tile.width / 2 + 5), int(y - tile.height / 2 + 6)))
        img.alpha_composite(tile, (int(x - tile.width / 2), int(y - tile.height / 2)))
        print(f"{kind:9s} at {int(x)},{int(y)} size {int(size)}")
    img.convert("RGB").save(dest)
    if preview:
        img.convert("RGB").resize((W // 3, H // 3), Image.LANCZOS).save(preview)


if __name__ == "__main__":
    main()
