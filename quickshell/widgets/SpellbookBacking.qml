import QtQuick
import ".."

// Spellbook backing — one page of an old grimoire: an oxblood leather cover with a gold-tooled
// border and brass corner protectors, a vellum page curving into the binding with a stack of
// page edges beside it, a silk ribbon bookmark, a pressed flower and an ink sketch of an ammonite.
// Painted procedurally from `seed`; the leather takes a hint of the theme's base color.
// The page area (for laying out text) is exposed as pageX / pageY / pageW / pageH.
Canvas {
    id: book

    property int seed: 3
    property color stain: Config.colors.base
    property color gilt: Config.colors.accent
    property real cornerRadius: Math.max(6, Config.settings.defaultWindowRadius)

    readonly property real cover: 14        // leather showing around the page
    readonly property real edges: 5         // stacked page edges, right and bottom
    readonly property real pageX: cover
    readonly property real pageY: cover
    readonly property real pageW: width - 2 * cover - edges
    readonly property real pageH: height - 2 * cover - edges

    antialiasing: true
    onSeedChanged: requestPaint()
    onStainChanged: requestPaint()
    onGiltChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const W = width, H = height;
        ctx.reset();
        if (W < 80 || H < 80)
            return;

        let sd = seed * 48271 + 11;
        const rnd = () => { sd = (sd * 16807) % 2147483647; return (sd - 1) / 2147483646; };
        const st = [stain.r * 255, stain.g * 255, stain.b * 255];
        const gt = [gilt.r * 255, gilt.g * 255, gilt.b * 255];
        const col = (c, k, a, toward, amt) => {
            const v = c.map((x, i) => Math.max(0, Math.min(255, Math.round((x + (toward[i] - x) * amt) * k))));
            return `rgba(${v[0]},${v[1]},${v[2]},${a === undefined ? 1 : a})`;
        };
        const leather = [96, 34, 28];
        const gold = (k, a) => col([200, 160, 82], k, a, gt, 0.3);
        const R = cornerRadius;
        const px = pageX, py = pageY, pw = pageW, ph = pageH;

        function roundRect(x, y, w, h, r) {
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.arcTo(x + w, y, x + w, y + h, r);
            ctx.arcTo(x + w, y + h, x, y + h, r);
            ctx.arcTo(x, y + h, x, y, r);
            ctx.arcTo(x, y, x + w, y, r);
            ctx.closePath();
        }

        // ── Leather cover: grained with value noise, creased, darker toward the edges ──
        roundRect(0.5, 0.5, W - 1, H - 1, R);
        ctx.fillStyle = col(leather, 1, 1, st, 0.18);
        ctx.fill();
        ctx.save();
        roundRect(0.5, 0.5, W - 1, H - 1, R);
        ctx.clip();
        const hash2 = (ix, iy, o) => {
            let h = Math.imul(ix, 374761393) + Math.imul(iy, 668265263) + Math.imul(seed * 31 + o, 1442695041);
            h = Math.imul(h ^ (h >>> 13), 1274126177);
            return ((h ^ (h >>> 16)) >>> 0) / 4294967296;
        };
        const vnoise = (x, y, o) => {
            const ix = Math.floor(x), iy = Math.floor(y), fx = x - ix, fy = y - iy;
            const u = fx * fx * (3 - 2 * fx), v = fy * fy * (3 - 2 * fy);
            const a = hash2(ix, iy, o), b = hash2(ix + 1, iy, o), c = hash2(ix, iy + 1, o), d = hash2(ix + 1, iy + 1, o);
            return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v;
        };
        const lb = leather.map((x, i) => x + (st[i] - x) * 0.18);
        for (let y = 0; y < H; y += 2) {
            for (let x = 0; x < W; x += 2) {
                if (x > px + 2 && x < px + pw + edges - 2 && y > py + 2 && y < py + ph + edges - 2)
                    continue;   // hidden under the page
                const n = 0.55 * vnoise(x / 30, y / 30, 1) + 0.3 * vnoise(x / 9, y / 9, 2) + 0.15 * vnoise(x / 3, y / 3, 3);
                const edge = Math.min(x, y, W - x, H - y);
                const k = (0.78 + 0.42 * n) * (edge < 6 ? 0.7 + edge * 0.05 : 1);
                ctx.fillStyle = `rgb(${(lb[0] * k) | 0},${(lb[1] * k) | 0},${(lb[2] * k) | 0})`;
                ctx.fillRect(x, y, 2, 2);
            }
        }
        // creases in the leather
        for (let i = 0; i < 40; i++) {
            const onSide = rnd();
            let x = onSide < 0.25 ? rnd() * px : onSide < 0.5 ? W - rnd() * (W - px - pw) : rnd() * W;
            let y = onSide < 0.5 ? rnd() * H : onSide < 0.75 ? rnd() * py : H - rnd() * (H - py - ph);
            const a = rnd() * 6.28, l = 3 + rnd() * 7;
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.quadraticCurveTo(x + Math.cos(a + 0.5) * l * 0.5, y + Math.sin(a + 0.5) * l * 0.5, x + Math.cos(a) * l, y + Math.sin(a) * l);
            ctx.strokeStyle = "rgba(20,4,2,0.35)";
            ctx.lineWidth = 0.7;
            ctx.stroke();
        }
        ctx.restore();

        // gold-tooled double rule and a blind-tooled (dark) rule just inside it
        roundRect(4.5, 4.5, W - 9, H - 9, Math.max(2, R - 4));
        ctx.strokeStyle = "rgba(30,6,2,0.5)";
        ctx.lineWidth = 2.4;
        ctx.stroke();
        ctx.strokeStyle = gold(1, 0.85);
        ctx.lineWidth = 1;
        ctx.stroke();
        roundRect(8, 8, W - 16, H - 16, Math.max(2, R - 7));
        ctx.strokeStyle = gold(0.9, 0.55);
        ctx.lineWidth = 0.7;
        ctx.stroke();
        // cover edge
        roundRect(0.5, 0.5, W - 1, H - 1, R);
        ctx.strokeStyle = "rgba(0,0,0,0.7)";
        ctx.lineWidth = 1;
        ctx.stroke();

        // ── Page block: stacked edges on the right and bottom, then the page itself ──
        for (let i = edges; i >= 1; i--) {
            ctx.fillStyle = i % 2 ? "rgba(196,176,134,1)" : "rgba(222,204,162,1)";
            ctx.fillRect(px + i, py + i, pw, ph);
            ctx.fillStyle = "rgba(90,64,30,0.35)";
            ctx.fillRect(px + i + pw - 1, py + i, 1, ph);
            ctx.fillRect(px + i, py + i + ph - 1, pw, 1);
        }
        // shadow the page block casts on the leather
        ctx.fillStyle = "rgba(0,0,0,0.35)";
        ctx.fillRect(px + edges + pw, py + edges + 2, 2, ph);
        ctx.fillRect(px + edges + 2, py + edges + ph, pw, 2);

        // the page: vellum, warmer and darker toward its edges
        const cream = [234, 216, 174], tea = [150, 104, 52];
        const pg = ctx.createLinearGradient(px, py, px + pw * 0.3, py + ph);
        pg.addColorStop(0, col(cream, 1.02, 1, gt, 0.05));
        pg.addColorStop(1, col(cream, 0.93, 1, gt, 0.05));
        ctx.fillStyle = pg;
        ctx.fillRect(px, py, pw, ph);
        ctx.save();
        ctx.beginPath();
        ctx.rect(px, py, pw, ph);
        ctx.clip();
        // age stains and foxing
        for (let i = 0; i < 9; i++) {
            const x = px + rnd() * pw, y = py + rnd() * ph, r = 30 + rnd() * 90;
            const sg = ctx.createRadialGradient(x, y, r * 0.2, x, y, r);
            sg.addColorStop(0, col(tea, 1, 0.04 + rnd() * 0.04, st, 0));
            sg.addColorStop(0.85, col(tea, 1, 0.06 + rnd() * 0.04, st, 0));
            sg.addColorStop(1, col(tea, 1, 0, st, 0));
            ctx.fillStyle = sg;
            ctx.fillRect(x - r, y - r, 2 * r, 2 * r);
        }
        for (let i = 0; i < Math.round(pw * ph / 260); i++) {
            ctx.beginPath();
            ctx.arc(px + rnd() * pw, py + rnd() * ph, 0.4 + rnd() * 1.1, 0, 2 * Math.PI);
            ctx.fillStyle = col(tea, 0.9, 0.1 + rnd() * 0.18, st, 0);
            ctx.fill();
        }
        // vellum edges darken with handling
        const eg = (x0, y0, x1, y1, a, rx, ry, rw, rh) => {
            const g = ctx.createLinearGradient(x0, y0, x1, y1);
            g.addColorStop(0, `rgba(110,70,30,${a})`);
            g.addColorStop(1, "rgba(110,70,30,0)");
            ctx.fillStyle = g;
            ctx.fillRect(rx, ry, rw, rh);
        };
        eg(px + pw, 0, px + pw - 14, 0, 0.22, px + pw - 14, py, 14, ph);
        eg(0, py, 0, py + 12, 0.18, px, py, pw, 12);
        eg(0, py + ph, 0, py + ph - 14, 0.24, px, py + ph - 14, pw, 14);
        // gutter: the page curves down into the binding on the left
        const gg = ctx.createLinearGradient(px, 0, px + 30, 0);
        gg.addColorStop(0, "rgba(40,20,6,0.55)");
        gg.addColorStop(0.35, "rgba(60,34,10,0.2)");
        gg.addColorStop(1, "rgba(60,34,10,0)");
        ctx.fillStyle = gg;
        ctx.fillRect(px, py, 30, ph);
        // a faint highlight where the page crests out of the gutter
        ctx.fillStyle = "rgba(255,250,235,0.18)";
        ctx.fillRect(px + 30, py, 6, ph);

        // ── Pressed flower in the top-left corner: flat, faded, a little translucent ──
        const pf = [178, 110, 104], pl = [110, 120, 70];
        const fx0 = px + 22, fy0 = py + 58;
        ctx.strokeStyle = col(pl, 0.8, 0.75, st, 0);
        ctx.lineWidth = 1.2;
        ctx.beginPath();
        ctx.moveTo(fx0, fy0);
        ctx.quadraticCurveTo(fx0 + 10, fy0 - 18, fx0 + 26, fy0 - 34);
        ctx.stroke();
        for (const [t, side] of [[0.35, 1], [0.6, -1]]) {
            const lx = fx0 + 26 * t * 0.9, ly = fy0 - 34 * t;
            ctx.save();
            ctx.translate(lx, ly);
            ctx.rotate(-0.9 + side * 0.9);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.quadraticCurveTo(6, -5, 13, 0);
            ctx.quadraticCurveTo(6, 5, 0, 0);
            ctx.fillStyle = col(pl, 0.95, 0.6, st, 0);
            ctx.fill();
            ctx.strokeStyle = col(pl, 0.6, 0.5, st, 0);
            ctx.lineWidth = 0.5;
            ctx.stroke();
            ctx.restore();
        }
        const flower = (x, y, r, rot, a) => {
            for (let i = 0; i < 5; i++) {
                const an = rot + i * 2 * Math.PI / 5;
                ctx.save();
                ctx.translate(x + Math.cos(an) * r * 0.55, y + Math.sin(an) * r * 0.55);
                ctx.rotate(an);
                ctx.beginPath();
                ctx.ellipse(-r * 0.6, -r * 0.36, r * 1.2, r * 0.72);
                ctx.fillStyle = col(pf, i % 2 ? 0.94 : 1, a, st, 0);
                ctx.fill();
                ctx.strokeStyle = col(pf, 0.6, a * 0.6, st, 0);
                ctx.lineWidth = 0.5;
                ctx.stroke();
                ctx.restore();
            }
            ctx.beginPath();
            ctx.arc(x, y, r * 0.35, 0, 2 * Math.PI);
            ctx.fillStyle = `rgba(196,156,72,${a})`;
            ctx.fill();
        };
        flower(fx0 + 27, fy0 - 36, 7.5, 0.4, 0.72);
        flower(fx0 + 6, fy0 - 22, 4.5, 1.2, 0.6);

        // Trilobite: head shield with glabella, eyes and genal spines, a segmented thorax
        // split into three lobes, and a rounded tail. Head points toward local -y.
        // fill: canvas fill style or null; passes: [{ o: offset, col, w }] stroked in order.
        function trilobite(cx, cy, L, rot, fill, passes) {
            ctx.save();
            ctx.translate(cx, cy);
            ctx.rotate(rot);
            const outline = () => {
                ctx.beginPath();
                ctx.moveTo(0, -0.5 * L);
                ctx.bezierCurveTo(0.22 * L, -0.5 * L, 0.33 * L, -0.36 * L, 0.32 * L, -0.2 * L);
                ctx.lineTo(0.36 * L, 0.02 * L);                       // genal spine
                ctx.lineTo(0.26 * L, -0.16 * L);
                ctx.bezierCurveTo(0.25 * L, 0.1 * L, 0.2 * L, 0.3 * L, 0.15 * L, 0.38 * L);
                ctx.bezierCurveTo(0.1 * L, 0.48 * L, -0.1 * L, 0.48 * L, -0.15 * L, 0.38 * L);
                ctx.bezierCurveTo(-0.2 * L, 0.3 * L, -0.25 * L, 0.1 * L, -0.26 * L, -0.16 * L);
                ctx.lineTo(-0.36 * L, 0.02 * L);
                ctx.lineTo(-0.32 * L, -0.2 * L);
                ctx.bezierCurveTo(-0.33 * L, -0.36 * L, -0.22 * L, -0.5 * L, 0, -0.5 * L);
                ctx.closePath();
            };
            if (fill) {
                outline();
                ctx.fillStyle = fill;
                ctx.fill();
            }
            for (const p of passes) {
                ctx.save();
                ctx.translate(p.o, p.o);
                ctx.strokeStyle = p.col;
                ctx.lineWidth = p.w;
                ctx.lineJoin = "round";
                outline();
                ctx.stroke();
                ctx.lineWidth = p.w * 0.75;
                ctx.beginPath();
                // rear edge of the head shield
                ctx.moveTo(-0.3 * L, -0.19 * L);
                ctx.quadraticCurveTo(0, -0.13 * L, 0.3 * L, -0.19 * L);
                // glabella (the raised central lobe of the head)
                ctx.moveTo(0.075 * L, -0.2 * L);
                ctx.bezierCurveTo(0.11 * L, -0.34 * L, 0.08 * L, -0.45 * L, 0, -0.45 * L);
                ctx.bezierCurveTo(-0.08 * L, -0.45 * L, -0.11 * L, -0.34 * L, -0.075 * L, -0.2 * L);
                // eyes
                ctx.moveTo(0.13 * L, -0.33 * L);
                ctx.quadraticCurveTo(0.2 * L, -0.33 * L, 0.2 * L, -0.25 * L);
                ctx.moveTo(-0.13 * L, -0.33 * L);
                ctx.quadraticCurveTo(-0.2 * L, -0.33 * L, -0.2 * L, -0.25 * L);
                // axial furrows splitting the body into three lobes
                ctx.moveTo(0.075 * L, -0.15 * L);
                ctx.quadraticCurveTo(0.07 * L, 0.15 * L, 0.035 * L, 0.42 * L);
                ctx.moveTo(-0.075 * L, -0.15 * L);
                ctx.quadraticCurveTo(-0.07 * L, 0.15 * L, -0.035 * L, 0.42 * L);
                ctx.stroke();
                // thorax segments, swept back at the ends
                ctx.lineWidth = p.w * 0.6;
                const segs = 9;
                for (let i = 0; i < segs; i++) {
                    const y = -0.11 * L + i * 0.052 * L, t = i / (segs - 1);
                    const hw = (0.255 - 0.06 * t) * L;
                    ctx.beginPath();
                    ctx.moveTo(-hw, y + 0.035 * L);
                    ctx.quadraticCurveTo(-hw * 0.55, y - 0.005 * L, -0.07 * L, y);
                    ctx.quadraticCurveTo(0, y + 0.012 * L, 0.07 * L, y);
                    ctx.quadraticCurveTo(hw * 0.55, y - 0.005 * L, hw, y + 0.035 * L);
                    ctx.stroke();
                }
                // tail segments
                for (let i = 0; i < 2; i++) {
                    const y = 0.37 * L + i * 0.035 * L;
                    ctx.beginPath();
                    ctx.moveTo(-0.11 * L + i * 0.03 * L, y - 0.01 * L);
                    ctx.quadraticCurveTo(0, y + 0.03 * L, 0.11 * L - i * 0.03 * L, y - 0.01 * L);
                    ctx.stroke();
                }
                ctx.restore();
            }
            ctx.restore();
        }
        // ── Ink sketch of an ammonite in the bottom-left margin ──
        const ink = "rgba(46,31,16,0.6)";
        for (const [ax, ay, aR] of [[px + 32, py + ph - 26, 15], [px + 58, py + ph - 13, 8], [px + 76, py + ph - 9, 5]]) {
        const b = Math.log(2) / (2 * Math.PI), tMax = 3 * 2 * Math.PI;
        const rr = th => aR * Math.exp(b * (th - tMax));
        ctx.strokeStyle = ink;
        ctx.lineWidth = 0.6;
        for (let th = 2 * Math.PI; th <= tMax; th += 0.38) {
            ctx.beginPath();
            ctx.moveTo(ax + rr(th) * Math.cos(th), ay + rr(th) * Math.sin(th));
            ctx.lineTo(ax + rr(th - 2 * Math.PI) * Math.cos(th), ay + rr(th - 2 * Math.PI) * Math.sin(th));
            ctx.stroke();
        }
        ctx.lineWidth = 0.9;
        ctx.beginPath();
        for (let th = 0.6; th <= tMax; th += 0.08) {
            const x = ax + rr(th) * Math.cos(th), y = ay + rr(th) * Math.sin(th);
            th === 0.6 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
        }
        ctx.stroke();
        }
        // and an ink study of a trilobite in the bottom-right margin
        trilobite(px + pw - 30, py + ph - 16, 36, -1.45, "rgba(46,31,16,0.07)", [{ "o": 0, "col": ink, "w": 0.85 }]);
        trilobite(px + pw - 62, py + ph - 9, 20, -1.75, "rgba(46,31,16,0.06)", [{ "o": 0, "col": ink, "w": 0.7 }]);
        ctx.restore();

        // ── Silk ribbon bookmark lying across the top of the page ──
        const rx = px + pw - 40, rw = 12, rTop = 4, rBot = py + 88;
        ctx.fillStyle = "rgba(40,10,4,0.3)";   // its shadow on the page
        ctx.beginPath();
        ctx.moveTo(rx + 2, rTop); ctx.lineTo(rx + rw + 2, rTop); ctx.lineTo(rx + rw + 2, rBot + 2);
        ctx.lineTo(rx + rw / 2 + 2, rBot - 6); ctx.lineTo(rx + 2, rBot + 2); ctx.closePath();
        ctx.fill();
        const rg = ctx.createLinearGradient(rx, 0, rx + rw, 0);
        rg.addColorStop(0, "rgba(110,18,14,1)");
        rg.addColorStop(0.4, "rgba(176,40,30,1)");
        rg.addColorStop(0.6, "rgba(160,32,24,1)");
        rg.addColorStop(1, "rgba(96,14,10,1)");
        ctx.beginPath();
        ctx.moveTo(rx, rTop); ctx.lineTo(rx + rw, rTop); ctx.lineTo(rx + rw, rBot);
        ctx.lineTo(rx + rw / 2, rBot - 8); ctx.lineTo(rx, rBot); ctx.closePath();
        ctx.fillStyle = rg;
        ctx.fill();
        // silk sheen threads
        ctx.strokeStyle = "rgba(255,190,170,0.18)";
        ctx.lineWidth = 0.6;
        for (let i = 2; i < rw; i += 2.5) {
            ctx.beginPath();
            ctx.moveTo(rx + i, rTop);
            ctx.lineTo(rx + i, rBot - 8 * (1 - Math.abs(i - rw / 2) / (rw / 2)) - 1);
            ctx.stroke();
        }

        // ── Brass corner protectors on the cover ──
        const cs = 22;
        const corners = [[0, 0, 0], [W, 0, Math.PI / 2], [W, H, Math.PI], [0, H, Math.PI * 1.5]];
        for (const c of corners) {
            ctx.save();
            ctx.translate(c[0], c[1]);
            ctx.rotate(c[2]);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(cs, 0);
            ctx.quadraticCurveTo(cs * 0.55, cs * 0.55, 0, cs);
            ctx.closePath();
            const bg = ctx.createLinearGradient(0, 0, cs * 0.6, cs * 0.6);
            bg.addColorStop(0, gold(1.25));
            bg.addColorStop(0.5, gold(0.95));
            bg.addColorStop(1, gold(0.55));
            ctx.fillStyle = bg;
            ctx.fill();
            ctx.strokeStyle = "rgba(30,14,2,0.85)";
            ctx.lineWidth = 1;
            ctx.stroke();
            // a little engraved curl and a rivet
            ctx.beginPath();
            ctx.arc(cs * 0.3, cs * 0.3, 3.4, 0, 2 * Math.PI);
            const rv = ctx.createRadialGradient(cs * 0.3 - 1, cs * 0.3 - 1, 0.3, cs * 0.3, cs * 0.3, 3.4);
            rv.addColorStop(0, gold(1.45));
            rv.addColorStop(1, gold(0.5));
            ctx.fillStyle = rv;
            ctx.fill();
            ctx.strokeStyle = "rgba(30,14,2,0.6)";
            ctx.lineWidth = 0.6;
            ctx.stroke();
            ctx.restore();
        }
    }
}
