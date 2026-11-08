#!/usr/bin/env python3
"""Recolor a black/white XCursor theme into two theme colors.

Dark pixels (cursor fill) -> FILL, light pixels (outline) -> OUTLINE, blended by luminance.
Usage: recolor_cursor.py SRC_THEME_DIR DEST_THEME_DIR NAME FILL_HEX OUTLINE_HEX
"""
import os, shutil, struct, sys

IMAGE_TYPE = 0xFFFD0002


def hex_rgb(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def recolor_file(data, fill, outline):
    if data[:4] != b"Xcur":
        return data
    out = bytearray(data)
    hsize, _ver, ntoc = struct.unpack_from("<III", data, 4)
    for i in range(ntoc):
        typ, _sub, pos = struct.unpack_from("<III", data, hsize + i * 12)
        if typ != IMAGE_TYPE:
            continue
        chsize = struct.unpack_from("<I", data, pos)[0]
        w, h = struct.unpack_from("<II", data, pos + 16)
        px = pos + chsize
        for j in range(w * h):
            off = px + j * 4
            b, g, r, a = data[off:off + 4]
            if a == 0:
                continue
            # un-premultiply
            r, g, b = (min(255, c * 255 // a) for c in (r, g, b))
            t = (0.299 * r + 0.587 * g + 0.114 * b) / 255.0
            nr, ng, nb = (round(f + (o - f) * t) for f, o in zip(fill, outline))
            out[off:off + 4] = bytes((nb * a // 255, ng * a // 255, nr * a // 255, a))
    return bytes(out)


def main():
    src, dest, name, fill, outline = sys.argv[1:6]
    fill, outline = hex_rgb(fill), hex_rgb(outline)
    srcc, destc = os.path.join(src, "cursors"), os.path.join(dest, "cursors")
    if os.path.isdir(dest):
        shutil.rmtree(dest)
    os.makedirs(destc)
    keep_file = os.path.join(src, ".keep-colors")  # cursors to copy without recoloring
    keep = set(open(keep_file).read().split()) if os.path.exists(keep_file) else set()
    for f in sorted(os.listdir(srcc)):
        sp, dp = os.path.join(srcc, f), os.path.join(destc, f)
        if os.path.islink(sp):
            os.symlink(os.readlink(sp), dp)
            continue
        if f in keep:
            shutil.copyfile(sp, dp)
            continue
        with open(sp, "rb") as fh:
            data = fh.read()
        with open(dp, "wb") as fh:
            fh.write(recolor_file(data, fill, outline))
    with open(os.path.join(dest, "index.theme"), "w") as fh:
        fh.write(f"[Icon Theme]\nName={name}\nComment=Recolored from {os.path.basename(src)}\n")


if __name__ == "__main__":
    main()
