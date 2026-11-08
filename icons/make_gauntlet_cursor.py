#!/usr/bin/env python3
"""Build the "Gauntlet-Source" cursor theme: Bibata-Modern-Classic with the
arrow / pointer / open-hand / grabbing cursors replaced by an armored knight's
gauntlet. theme-sync.sh then recolors it per theme like any other source.

Usage: make_gauntlet_cursor.py [DEST_DIR] [--preview PNG]
"""
import math, os, shutil, struct, sys
from PIL import Image, ImageDraw, ImageFilter, ImageChops

S = 4                      # supersample: 256 design units -> 1024 px
N = 256 * S
SIZES = [22, 24, 28, 32, 40, 48, 56, 64, 72, 80, 88, 96]
BIBATA = "/usr/share/icons/Bibata-Modern-Classic"
INK = (18, 18, 20, 255)
LINE = 2.4                 # outline width in design units


def shade(t):
    """Mirror-polished steel profile across a plate (0 = left edge, 1 = right):
    hot white specular streak, a deep horizon reflection band, then a rim light."""
    g = lambda c, w: math.exp(-((t - c) / w) ** 2)
    v = (0.30 + 0.55 * g(0.24, 0.12) + 0.45 * g(0.22, 0.035)   # broad sheen + sharp glint
         - 0.32 * g(0.50, 0.07) + 0.30 * g(0.76, 0.10)           # dark band, sky fill
         + 0.25 * g(0.93, 0.03))                                  # thin rim light
    v -= 0.22 * g(1.0, 0.05) + 0.14 * g(0.0, 0.05)              # shadowed edges
    v = max(0.0, min(1.0, v))
    # Cool blue-grey tint that blows out to pure white in the highlights.
    return tuple(max(0, min(255, round(255 * (v * k + (1 - k) * v ** 3))))
                 for k in (0.84, 0.91, 1.0))


GRAD = [shade(i / 255) for i in range(256)]  # (r, g, b)


def sc(pts):
    return [(x * S, y * S) for x, y in pts]


def arc(cx, cy, rx, ry, a0, a1, n=24):
    return [(cx + rx * math.cos(math.radians(a0 + (a1 - a0) * i / n)),
             cy + ry * math.sin(math.radians(a0 + (a1 - a0) * i / n))) for i in range(n + 1)]


def lame(x0, x1, y0, y1, bulge=6, round_top=False):
    """A curved armor plate. round_top makes a fingertip cap."""
    cx, w = (x0 + x1) / 2, (x1 - x0) / 2
    if round_top:
        top = arc(cx, y0 + w, w, w, 180, 360)
    else:
        top = arc(cx, y0 + bulge, w, bulge, 180, 360)
    bottom = arc(cx, y1 - bulge, w, bulge, 0, 180)
    return top + bottom


class Canvas:
    def __init__(self):
        self.img = Image.new("RGBA", (N, N), (0, 0, 0, 0))
        self.d = ImageDraw.Draw(self.img)

    def plate(self, poly, light=1.0, axis=None):
        p = sc(poly)
        xs, ys = [q[0] for q in p], [q[1] for q in p]
        bx0, by0, bx1, by1 = int(min(xs)), int(min(ys)), int(max(xs)) + 1, int(max(ys)) + 1
        bw, bh = bx1 - bx0, by1 - by0
        strip = Image.new("RGBA", (256, 1))
        strip.putdata([tuple(min(255, round(c * light)) for c in rgb) + (255,) for rgb in GRAD])
        metal = strip.resize((bw, bh), Image.BILINEAR)
        # Top of each plate catches more light than the bottom.
        vert = Image.new("L", (1, 256))
        vert.putdata([min(255, round(255 * (1.08 - 0.30 * (i / 255) ** 1.5))) for i in range(256)])
        vert = vert.resize((bw, bh), Image.BILINEAR)
        r, g_, b_, al = metal.split()
        metal = Image.merge("RGBA", [ImageChops.multiply(ch, vert) for ch in (r, g_, b_)] + [al])
        mask = Image.new("L", (N, N), 0)
        ImageDraw.Draw(mask).polygon(p, fill=255)
        self.img.paste(metal, (bx0, by0), mask.crop((bx0, by0, bx1, by1)))
        self.d.line(p + [p[0], p[1]], fill=INK, width=round(LINE * S), joint="curve")

    def line(self, pts, fill=INK, w=LINE):
        self.d.line(sc(pts), fill=fill, width=round(w * S), joint="curve")

    def ridge(self, pts):
        """Embossed crease: dark line with a highlight beside it."""
        self.line([(x + 1.6, y) for x, y in pts], fill=(235, 235, 235, 255), w=1.4)
        self.line(pts, w=1.6)

    def rivet(self, x, y, r=3.2):
        self.d.ellipse([(x - r) * S, (y - r) * S, (x + r) * S, (y + r) * S],
                       fill=(96, 104, 116, 255), outline=INK, width=S)
        h = r * 0.45
        self.d.ellipse([(x - h - 0.8) * S, (y - h - 0.8) * S, (x + h - 0.8) * S, (y + h - 0.8) * S],
                       fill=(245, 245, 245, 255))

    def sparkle(self, x, y, r=9):
        """Four-point glint star."""
        w = r * 0.22
        pts = [(x, y - r), (x + w, y - w), (x + r, y), (x + w, y + w),
               (x, y + r), (x - w, y + w), (x - r, y), (x - w, y - w)]
        self.d.polygon(sc(pts), fill=(255, 255, 255, 255))
        self.d.ellipse([(x - 2) * S, (y - 2) * S, (x + 2) * S, (y + 2) * S], fill=(255, 255, 255, 255))

    def finish(self):
        """Add a solid outer border so the cursor reads on any background."""
        a = self.img.getchannel("A")
        grown = a.filter(ImageFilter.MaxFilter(2 * S + 1))
        back = Image.new("RGBA", (N, N), INK)
        back.putalpha(grown)
        back.alpha_composite(self.img)
        return back


def cuff_and_back(c, thumb):
    # Flared cuff with a rolled rim.
    cuff = [(84, 186), (168, 186)] + arc(126, 238, 70, 12, 0, 180)
    c.plate(cuff, 0.95)
    c.ridge([(126, 196), (126, 246)])
    for x, y in [(72, 232), (100, 240), (152, 240), (180, 232)]:
        c.rivet(x, y)
    c.plate(lame(80, 172, 172, 196, 4), 1.0)
    for x in (92, 160):
        c.rivet(x, 184, 2.8)
    # Back-of-hand plate.
    c.plate([(78, 118), (174, 124), (178, 152), (170, 182), (84, 182), (78, 150)], 1.0)
    c.ridge([(128, 136), (127, 176)])
    thumb(c)


def thumb_tucked(c):
    c.plate(lame(40, 64, 100, 142, 5, round_top=True), 1.0)
    c.plate([(84, 180), (58, 162), (46, 134), (66, 124), (88, 148)], 1.0)
    c.rivet(68, 150, 2.6)


def thumb_out(c):
    c.plate([(26, 98), (42, 84), (68, 114), (52, 130)], 1.0)
    c.plate([(84, 180), (56, 160), (42, 124), (62, 114), (88, 146)], 1.0)
    c.rivet(66, 146, 2.6)


def finger(c, x0, x1, top, bottom=128):
    """Three overlapping lames + fingertip, base lames drawn last (on top)."""
    h = (bottom - top) / 3
    c.plate(lame(x0 + 2, x1 - 2, top, top + h + 10, 5, round_top=True), 1.0)
    c.plate(lame(x0 + 1, x1 - 1, top + h, top + 2 * h + 10, 5), 1.0)
    c.plate(lame(x0, x1, top + 2 * h, bottom, 5), 1.0)


def knuckles(c, spans, y0=104, y1=152):
    for i, (x0, x1) in enumerate(spans):
        c.plate(lame(x0, x1, y0 + i * 3, y1 + i, 8), 1.0)
        c.rivet((x0 + x1) / 2, y0 + i * 3 + 14, 2.4)


def pointer():
    c = Canvas()
    cuff_and_back(c, thumb_tucked)
    knuckles(c, [(106, 132), (130, 154), (152, 174)])
    finger(c, 76, 108, 6, 128)
    c.sparkle(85, 22, 8)
    c.sparkle(94, 212, 10)
    return c.finish(), (92, 6)


def open_hand():
    c = Canvas()
    cuff_and_back(c, thumb_out)
    finger(c, 150, 172, 50, 132)
    finger(c, 126, 152, 26, 130)
    finger(c, 100, 128, 16, 128)
    finger(c, 74, 102, 30, 128)
    c.sparkle(108, 32, 8)
    c.sparkle(94, 212, 10)
    return c.finish(), (124, 120)


def fist():
    c = Canvas()
    cuff_and_back(c, lambda c: None)
    knuckles(c, [(76, 102), (100, 128), (126, 152), (150, 174)], 92, 146)
    # Curled finger fronts under the knuckles.
    for i, (x0, x1) in enumerate([(78, 102), (102, 128), (128, 152), (152, 172)]):
        c.plate(lame(x0, x1, 138 + i * 2, 166 + i, 5), 0.85)
    # Thumb wrapped across the front.
    c.plate([(76, 182), (64, 156), (78, 142), (124, 148), (132, 162), (122, 173), (90, 175)], 1.0)
    c.rivet(84, 158, 2.6)
    c.sparkle(84, 104, 8)
    c.sparkle(94, 212, 10)
    return c.finish(), (124, 130)


def arrow():
    """The pointer gauntlet tilted so the fingertip points up-left."""
    img, (hx, hy) = pointer()
    ang = 28
    rot = img.rotate(ang, resample=Image.BICUBIC, expand=True)
    # Where the fingertip landed after rotation (PIL rotates CCW about centre).
    cx, cy = N / 2, N / 2
    dx, dy = hx * S - cx, hy * S - cy
    r = math.radians(ang)
    tx = rot.width / 2 + dx * math.cos(r) + dy * math.sin(r)
    ty = rot.height / 2 - dx * math.sin(r) + dy * math.cos(r)
    bbox = rot.getchannel("A").getbbox()
    m = 3 * S
    x0, y0 = min(tx - m, bbox[0] - m), min(ty - m, bbox[1] - m)
    side = max(bbox[2] + m - x0, bbox[3] + m - y0)
    crop = rot.crop((round(x0), round(y0), round(x0 + side), round(y0 + side)))
    out = crop.resize((N, N), Image.LANCZOS)
    k = N / side
    return out, ((tx - x0) * k / S, (ty - y0) * k / S)


def xcursor(img, hot, path):
    images = []
    for s in SIZES:
        im = img.resize((s, s), Image.LANCZOS)
        px = bytearray()
        for r, g, b, a in im.getdata():
            px += bytes((b * a // 255, g * a // 255, r * a // 255, a))
        hx = min(s - 1, round(hot[0] * s / 256))
        hy = min(s - 1, round(hot[1] * s / 256))
        images.append((s, struct.pack("<9I", 36, 0xFFFD0002, s, 1, s, s, hx, hy, 0) + px))
    n = len(images)
    pos = 16 + 12 * n
    toc, body = b"", b""
    for s, chunk in images:
        toc += struct.pack("<3I", 0xFFFD0002, s, pos + len(body))
        body += chunk
    with open(path, "wb") as fh:
        fh.write(b"Xcur" + struct.pack("<3I", 16, 0x10000, n) + toc + body)


def main():
    args = sys.argv[1:]
    preview = None
    if "--preview" in args:
        i = args.index("--preview"); preview = args[i + 1]; del args[i:i + 2]
    dest = args[0] if args else os.path.expanduser("~/.local/share/icons/Gauntlet-Source")
    shapes = {"left_ptr": arrow(), "hand2": pointer(), "hand1": open_hand(), "grabbing": fist()}
    if preview:
        sheet = Image.new("RGBA", (4 * 270, 270), (0, 0, 0, 0))
        for i, (img, _) in enumerate(shapes.values()):
            sheet.alpha_composite(img.resize((256, 256), Image.LANCZOS), (i * 270 + 7, 7))
        sheet.save(preview)
        return
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    shutil.copytree(BIBATA, dest, symlinks=True)
    for name, (img, hot) in shapes.items():
        xcursor(img, hot, os.path.join(dest, "cursors", name))
    with open(os.path.join(dest, ".keep-colors"), "w") as fh:  # recolor_cursor.py copies these untouched
        fh.write("\n".join(shapes) + "\n")
    with open(os.path.join(dest, "index.theme"), "w") as fh:
        fh.write("[Icon Theme]\nName=Gauntlet-Source\nComment=Bibata with knight's gauntlet pointers\n")


if __name__ == "__main__":
    main()
