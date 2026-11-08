import QtQuick
import ".."

// Stone backing — a carved slab of dark slate, lightly tinted toward the theme.
// Mottled patches, speckled grain, a few hairline cracks and a chiselled bevel.
// Painted procedurally from `seed`, so each widget gets its own stone that never changes on redraw.
// Use: StoneBacking { anchors.fill: parent; visible: root.widgetBackground; seed: 7 }
Canvas {
    id: stone

    property int seed: 1
    property color stain: Config.colors.base
    property real cornerRadius: Config.settings.defaultWindowRadius
    // Ammonite fossils pressed into the slate, tucked into the corners away from the text.
    property bool fossils: true
    onFossilsChanged: requestPaint()
    // Wildflowers sprouting from the corners the fossils leave free.
    property bool flowers: true
    property real flowerSize: 1.7   // scales the whole sprig: blooms, stems, leaves, moss
    property color bloom: Config.colors.accent
    onFlowersChanged: requestPaint()
    onFlowerSizeChanged: requestPaint()
    onBloomChanged: requestPaint()

    opacity: 0.97
    antialiasing: true
    onStainChanged: requestPaint()
    onSeedChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const W = width, H = height;
        ctx.reset();
        if (W < 40 || H < 40)
            return;

        let s = (seed * 9301 + 49297) % 233280 + 1;
        const rnd = () => { s = (s * 16807) % 2147483647; return (s - 1) / 2147483646; };
        const st = [stain.r * 255, stain.g * 255, stain.b * 255];
        // slate tones mixed 15% toward the theme's base color
        const tone = (c, k, a) => {
            const v = c.map((x, i) => Math.max(0, Math.min(255, Math.round((x + (st[i] - x) * 0.15) * k))));
            return `rgba(${v[0]},${v[1]},${v[2]},${a === undefined ? 1 : a})`;
        };
        const slate = [84, 83, 82], dark = [24, 24, 26], light = [170, 168, 160];
        const R = Math.max(2, cornerRadius), B = 9; // B: width of the chiselled bevel

        function roundRect(x, y, w, h, r) {
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.arcTo(x + w, y, x + w, y + h, r);
            ctx.arcTo(x + w, y + h, x, y + h, r);
            ctx.arcTo(x, y + h, x, y, r);
            ctx.arcTo(x, y, x + w, y, r);
            ctx.closePath();
        }

        // Slab body
        roundRect(0.5, 0.5, W - 1, H - 1, R);
        const body = ctx.createLinearGradient(0, 0, W * 0.3, H);
        body.addColorStop(0, tone(slate, 1.08));
        body.addColorStop(1, tone(slate, 0.86));
        ctx.fillStyle = body;
        ctx.fill();

        ctx.save();
        roundRect(0.5, 0.5, W - 1, H - 1, R);
        ctx.clip();

        // ── Rock texture: fractal value noise painted in 2px cells ──
        // Several octaves give variation at every scale like real stone; a stretched octave adds the
        // fine parallel cleavage of slate; a low-frequency octave adds faint rusty iron staining.
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
        const fbm = (x, y) => {
            let sum = 0, amp = 0.5, f = 1 / 110, norm = 0;
            for (let o = 0; o < 6; o++) {
                sum += amp * vnoise(x * f, y * f, o);
                norm += amp;
                amp *= 0.55;
                f *= 2.1;
            }
            return sum / norm;
        };
        const ang = (hash2(1, 2, 99) - 0.5) * 0.5;          // cleavage direction, near horizontal
        const ca = Math.cos(ang), sa = Math.sin(ang);
        const sb = [slate[0] + (st[0] - slate[0]) * 0.15, slate[1] + (st[1] - slate[1]) * 0.15, slate[2] + (st[2] - slate[2]) * 0.15];
        const rust = [118, 82, 56];
        const cell = 2;
        for (let y = 0; y < H; y += cell) {
            for (let x = 0; x < W; x += cell) {
                let n = fbm(x, y);
                n = Math.max(0, Math.min(1, (n - 0.5) * 2.1 + 0.5));             // stretch contrast
                const along = x * ca + y * sa, across = -x * sa + y * ca;
                const cl = vnoise(along / 160, across / 2.6, 7) - 0.5;           // cleavage streaks
                const light = 1 - 0.16 * (x / W) - 0.2 * (y / H);                // lit from the top-left
                const k = (0.7 + 0.5 * n + 0.13 * cl) * (0.92 + light * 0.14);
                const rs = Math.max(0, vnoise(x / 170, y / 170, 11) - 0.66) * 1.6; // iron staining
                const r = (sb[0] * (1 - rs) + rust[0] * rs) * k, g = (sb[1] * (1 - rs) + rust[1] * rs) * k, b = (sb[2] * (1 - rs) + rust[2] * rs) * k;
                ctx.fillStyle = `rgb(${r | 0},${g | 0},${b | 0})`;
                ctx.fillRect(x, y, cell, cell);
            }
        }

        // Quartz veins: pale, slightly glowing mineral seams with darker selvedges
        let vs = seed * 7919 + 17;
        const vr = () => { vs = (vs * 16807) % 2147483647; return (vs - 1) / 2147483646; };
        const veins = 1 + Math.floor(vr() * 2);
        for (let v = 0; v < veins; v++) {
            let x = vr() * W, y = vr() < 0.5 ? 0 : H, a = (y === 0 ? 1 : -1) * (Math.PI / 2) + (vr() - 0.5) * 1.6;
            const pts = [[x, y]];
            for (let i = 0; i < 40; i++) {
                a += (vr() - 0.5) * 0.5;
                x += Math.cos(a) * (6 + vr() * 8);
                y += Math.sin(a) * (6 + vr() * 8);
                pts.push([x, y]);
                if (x < -10 || x > W + 10 || y < -10 || y > H + 10)
                    break;
            }
            const wv = 1 + vr() * 1.8;
            for (const pass of [[wv * 5, "rgba(215,212,200,0.08)", 0], [wv + 2, "rgba(10,10,12,0.28)", 0.8], [wv, "rgba(218,214,200,0.5)", 0]]) {
                ctx.beginPath();
                pts.forEach((p, i) => i === 0 ? ctx.moveTo(p[0] + pass[2], p[1] + pass[2]) : ctx.lineTo(p[0] + pass[2], p[1] + pass[2]));
                ctx.strokeStyle = pass[1];
                ctx.lineWidth = pass[0];
                ctx.lineJoin = "round";
                ctx.stroke();
            }
            // a thin branch off the main vein
            const bi = Math.floor(pts.length * (0.3 + vr() * 0.4));
            if (pts[bi]) {
                let bx = pts[bi][0], by = pts[bi][1], ba = a + (vr() < 0.5 ? 1 : -1) * (0.6 + vr() * 0.6);
                ctx.beginPath();
                ctx.moveTo(bx, by);
                for (let i = 0; i < 6; i++) {
                    ba += (vr() - 0.5) * 0.6;
                    bx += Math.cos(ba) * (5 + vr() * 6);
                    by += Math.sin(ba) * (5 + vr() * 6);
                    ctx.lineTo(bx, by);
                }
                ctx.strokeStyle = "rgba(218,214,200,0.35)";
                ctx.lineWidth = wv * 0.6;
                ctx.stroke();
            }
        }

        // Speckled grain
        const specks = Math.round(W * H / 16);
        for (let i = 0; i < specks; i++) {
            const x = rnd() * W, y = rnd() * H, sz = rnd() < 0.9 ? 1 : 1.5 + rnd() * 1.5;
            const v = rnd();
            ctx.fillStyle = v < 0.5 ? tone(dark, 1, 0.22 + rnd() * 0.35) : (v < 0.95 ? tone(light, 1, 0.08 + rnd() * 0.16) : "rgba(232,230,220,0.45)");
            ctx.fillRect(x, y, sz, sz);
        }
        // Larger mineral flecks and pits
        for (let i = 0; i < Math.round(W * H / 900); i++) {
            const x = rnd() * W, y = rnd() * H, r = 1.2 + rnd() * 2.6;
            const pit = rnd() < 0.6;
            ctx.beginPath();
            ctx.ellipse(x, y, r * (1 + rnd()), r);
            ctx.fillStyle = pit ? tone(dark, 0.7, 0.45 + rnd() * 0.3) : tone(light, 1.1, 0.18 + rnd() * 0.2);
            ctx.fill();
            if (pit) {
                ctx.beginPath();
                ctx.ellipse(x + 0.6, y + 0.8, r * (1 + rnd()) * 0.8, r * 0.7);
                ctx.fillStyle = tone(light, 1, 0.12);
                ctx.fill();
            }
        }

        // Hairline cracks: a dark line with a faint lit edge beside it
        const cracks = 1 + Math.floor(rnd() * 2);
        for (let c = 0; c < cracks; c++) {
            const fromLeft = rnd() < 0.5;
            let x = fromLeft ? 0 : W, y = H * (0.15 + rnd() * 0.7);
            let a = (fromLeft ? 0 : Math.PI) + (rnd() - 0.5) * 1.2;
            const pts = [[x, y]];
            const steps = 6 + Math.floor(rnd() * 6);
            for (let i = 0; i < steps; i++) {
                a += (rnd() - 0.5) * 0.9;
                x += Math.cos(a) * (8 + rnd() * 14);
                y += Math.sin(a) * (8 + rnd() * 14);
                pts.push([x, y]);
            }
            for (const pass of [[tone(light, 1, 0.16), 1, 1], [tone(dark, 0.6, 0.75), 1.1, 0]]) {
                ctx.beginPath();
                pts.forEach((p, i) => i === 0 ? ctx.moveTo(p[0] + pass[2], p[1] + pass[2]) : ctx.lineTo(p[0] + pass[2], p[1] + pass[2]));
                ctx.strokeStyle = pass[0];
                ctx.lineWidth = pass[1];
                ctx.stroke();
            }
        }

        // Fossil ammonites: a pale mineral fill, then the shell carved in shallow relief
        // (light edge offset down-right, dark groove on top).
        function fossil(cx, cy, R0, rot, strength) {
            const b = Math.log(2) / (2 * Math.PI);           // each whorl doubles in size
            const turns = 3.2, tMax = turns * 2 * Math.PI;
            const r = th => R0 * Math.exp(b * (th - tMax));
            const pt = (th, rr, o) => [cx + o + rr * Math.cos(th + rot), cy + o + rr * Math.sin(th + rot)];

            const fill = ctx.createRadialGradient(cx, cy, R0 * 0.1, cx, cy, R0);
            fill.addColorStop(0, tone(light, 1.05, 0.16 * strength));
            fill.addColorStop(0.85, tone(light, 1, 0.10 * strength));
            fill.addColorStop(1, tone(light, 1, 0));
            ctx.beginPath();
            ctx.arc(cx, cy, R0, 0, 2 * Math.PI);
            ctx.fillStyle = fill;
            ctx.fill();

            for (const pass of [{ o: 1, col: tone(light, 1.1, 0.30 * strength) }, { o: 0, col: tone(dark, 0.7, 0.62 * strength) }]) {
                ctx.strokeStyle = pass.col;
                // ribs across each whorl, slightly curved like real ammonite ribs
                ctx.lineWidth = Math.max(0.6, R0 / 40);
                const step = 0.2 + 6 / (R0 + 20);
                for (let th = 2 * Math.PI + 0.4; th <= tMax; th += step) {
                    const r1 = r(th), r2 = r(th - 2 * Math.PI);
                    const p1 = pt(th, r1, pass.o), p2 = pt(th, r2, pass.o), pm = pt(th - 0.12, (r1 + r2) / 2, pass.o);
                    ctx.beginPath();
                    ctx.moveTo(p1[0], p1[1]);
                    ctx.quadraticCurveTo(pm[0], pm[1], p2[0], p2[1]);
                    ctx.stroke();
                }
                // the spiral (suture between whorls) and the outer rim
                ctx.lineWidth = Math.max(1, R0 / 22);
                ctx.beginPath();
                for (let th = 0.8; th <= tMax; th += 0.06) {
                    const p = pt(th, r(th), pass.o);
                    th === 0.8 ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]);
                }
                ctx.stroke();
                ctx.beginPath();
                ctx.arc(cx + pass.o, cy + pass.o, R0, 0, 2 * Math.PI);
                ctx.stroke();
            }
        }
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
        const corners = [[0, 0], [1, 0], [0, 1], [1, 1]];
        const first = Math.floor(rnd() * 4);
        const second = (first + 1 + Math.floor(rnd() * 3)) % 4;
        if (fossils) {
            // a large one running off the edge of one corner
            const bigR = Math.min(60, Math.min(W, H) * 0.19) * (0.85 + rnd() * 0.3);
            const c1 = corners[first];
            fossil(c1[0] ? W - bigR * 0.55 : bigR * 0.55, c1[1] ? H - bigR * 0.55 : bigR * 0.55, bigR, rnd() * 6.28, 1);
            // a small one, whole, in another corner
            const smR = 14 + rnd() * 6, inset = B + smR + 7;
            const c2 = corners[second];
            fossil(c2[0] ? W - inset : inset, c2[1] ? H - inset : inset, smR, rnd() * 6.28, 0.9);
            // a scatter of ammonites all round the edges, kept out of the text in the middle
            const placed = [[c1[0] ? W - bigR * 0.55 : bigR * 0.55, c1[1] ? H - bigR * 0.55 : bigR * 0.55, bigR],
                            [c2[0] ? W - inset : inset, c2[1] ? H - inset : inset, smR]];
            // trilobites lying among the ammonites
            for (let k = 0, tries = 0; k < 4 && tries < 800; tries++) {
                const L = 46 + rnd() * 16, r0 = L * 0.4, m = B + r0 + 2;
                const e = Math.floor(rnd() * 4), u = 0.1 + rnd() * 0.8;
                const fx = e === 0 ? m : e === 1 ? W - m : W * u;
                const fy = e === 2 ? m : e === 3 ? H - m : H * u;
                if (placed.some(q => Math.hypot(q[0] - fx, q[1] - fy) < q[2] + r0 + 4))
                    continue;
                placed.push([fx, fy, r0]);
                trilobite(fx, fy, L, rnd() * 6.28, tone(light, 1.05, 0.18),
                          [{ "o": 1, "col": tone(light, 1.15, 0.42), "w": 1.3 }, { "o": 0, "col": tone(dark, 0.6, 0.85), "w": 1.3 }]);
                k++;
            }
            const count = 8 + Math.floor(rnd() * 4);
            for (let i = 0, tries = 0; i < count && tries < 200; tries++) {
                const r0 = 8 + rnd() * 9, m = B + r0 + 4;
                // pick a point on the border band: one of the four edges, anywhere along it
                const e = Math.floor(rnd() * 4), u = 0.08 + rnd() * 0.84;
                const fx = e === 0 ? m + rnd() * 6 : e === 1 ? W - m - rnd() * 6 : W * u;
                const fy = e === 2 ? m + rnd() * 6 : e === 3 ? H - m - rnd() * 6 : H * u;
                if (placed.some(q => Math.hypot(q[0] - fx, q[1] - fy) < q[2] + r0 + 6))
                    continue;
                placed.push([fx, fy, r0]);
                fossil(fx, fy, r0, rnd() * 6.28, 0.9 + rnd() * 0.3);
                i++;
            }
            // and a broken one peeking in from an edge opposite the big fossil
            const pr = Math.min(36, Math.min(W, H) * 0.12);
            fossil(c1[0] ? pr * 0.35 : W - pr * 0.35, H * (0.35 + rnd() * 0.3), pr, rnd() * 6.28, 0.75);
        }

        // Darken toward the edges so text in the middle reads clearly
        const vg = ctx.createRadialGradient(W / 2, H / 2, Math.min(W, H) * 0.15, W / 2, H / 2, Math.max(W, H) * 0.7);
        vg.addColorStop(0, "rgba(0,0,0,0.10)");
        vg.addColorStop(1, "rgba(0,0,0,0.40)");
        ctx.fillStyle = vg;
        ctx.fillRect(0, 0, W, H);

        // Chiselled bevel: light catches the top-left faces, shadow on the bottom-right
        const bevel = (x0, y0, x1, y1, x2, y2, x3, y3, col) => {
            ctx.beginPath();
            ctx.moveTo(x0, y0); ctx.lineTo(x1, y1); ctx.lineTo(x2, y2); ctx.lineTo(x3, y3);
            ctx.closePath();
            ctx.fillStyle = col;
            ctx.fill();
        };
        bevel(0, 0, W, 0, W - B, B, B, B, tone(light, 1, 0.20));          // top
        bevel(0, 0, B, B, B, H - B, 0, H, tone(light, 1, 0.12));          // left
        bevel(W, 0, W, H, W - B, H - B, W - B, B, "rgba(0,0,0,0.30)");    // right
        bevel(0, H, B, H - B, W - B, H - B, W, H, "rgba(0,0,0,0.42)");    // bottom
        ctx.restore();

        // Carved inner edge of the bevel
        ctx.strokeStyle = "rgba(0,0,0,0.45)";
        ctx.lineWidth = 1;
        ctx.strokeRect(B + 0.5, B + 0.5, W - 2 * B - 1, H - 2 * B - 1);
        ctx.strokeStyle = tone(light, 1, 0.14);
        ctx.strokeRect(B + 1.5, B + 1.5, W - 2 * B - 3, H - 2 * B - 3);

        // Wildflowers: sprigs growing out of the free corners, stems hugging the edges
        const bl = [bloom.r * 255, bloom.g * 255, bloom.b * 255];
        const tint = (c, k, a) => {
            const v = c.map((x, i) => Math.max(0, Math.min(255, Math.round((x + (bl[i] - x) * 0.3) * k))));
            return `rgba(${v[0]},${v[1]},${v[2]},${a === undefined ? 1 : a})`;
        };
        const leafC = [104, 132, 70], mossC = [92, 118, 58];
        const petals = [[236, 150, 150], [242, 228, 204], [236, 150, 150]];
        function flower(x, y, r, rot, col) {
            for (let i = 0; i < 5; i++) {
                const a = rot + i * 2 * Math.PI / 5;
                ctx.save();
                ctx.translate(x + Math.cos(a) * r * 0.55, y + Math.sin(a) * r * 0.55);
                ctx.rotate(a);
                ctx.beginPath();
                ctx.ellipse(-r * 0.55, -r * 0.33, r * 1.1, r * 0.66);
                ctx.fillStyle = tint(col, i % 2 ? 0.92 : 1, 0.96);
                ctx.fill();
                ctx.strokeStyle = "rgba(40,16,10,0.5)";
                ctx.lineWidth = 0.6;
                ctx.stroke();
                ctx.restore();
            }
            ctx.beginPath();
            ctx.arc(x, y, r * 0.38, 0, 2 * Math.PI);
            ctx.fillStyle = "rgba(226,184,84,1)";
            ctx.fill();
            ctx.strokeStyle = "rgba(60,36,6,0.7)";
            ctx.lineWidth = 0.6;
            ctx.stroke();
        }
        function leaf(x, y, ang, len) {
            ctx.save();
            ctx.translate(x, y);
            ctx.rotate(ang);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.quadraticCurveTo(len * 0.5, -len * 0.4, len, 0);
            ctx.quadraticCurveTo(len * 0.5, len * 0.4, 0, 0);
            ctx.fillStyle = tint(leafC, 0.85 + rnd() * 0.3);
            ctx.fill();
            ctx.strokeStyle = "rgba(10,20,4,0.5)";
            ctx.lineWidth = 0.5;
            ctx.stroke();
            ctx.restore();
        }
        // One sprig from corner (sx, sy); ux/uy point along the horizontal edge inward, vx/vy along the vertical edge.
        function sprig(cx, cy, ux, vy) {
            const fs = flowerSize;
            // moss tuft in the corner
            for (let i = 0; i < 26; i++) {
                const a = rnd() * Math.PI / 2, d = rnd() * 14 * fs;
                ctx.beginPath();
                ctx.arc(cx + ux * (B - 2 + Math.cos(a) * d), cy + vy * (B - 2 + Math.sin(a) * d), (1 + rnd() * 1.8) * Math.sqrt(fs), 0, 2 * Math.PI);
                ctx.fillStyle = tint(mossC, 0.7 + rnd() * 0.5, 0.85);
                ctx.fill();
            }
            const stems = 3;
            for (let k = 0; k < stems; k++) {
                // fan the stems between "along the bottom/top edge" and "along the side edge"
                const f = (k + 0.5) / stems, len = (24 + rnd() * 12) * fs;
                // bottom-corner sprigs lean along the bottom edge so they stay under the text
                const a0 = f * Math.PI / 2 * (vy < 0 ? 0.62 : 1);
                const ex = cx + ux * (B + Math.cos(a0) * len), ey = cy + vy * (B + Math.sin(a0) * len);
                const mx = cx + ux * (B + Math.cos(a0) * len * 0.3), my = cy + vy * (B + Math.sin(a0) * len * 0.75);
                ctx.beginPath();
                ctx.moveTo(cx + ux * (B - 1), cy + vy * (B - 1));
                ctx.quadraticCurveTo(mx, my, ex, ey);
                ctx.strokeStyle = tint(leafC, 0.75, 0.95);
                ctx.lineWidth = 1.1 * Math.sqrt(fs);
                ctx.stroke();
                // leaves along the stem
                for (let j = 1; j <= 2; j++) {
                    const tt = j / 3.2;
                    const lx = (1 - tt) * (1 - tt) * (cx + ux * (B - 1)) + 2 * (1 - tt) * tt * mx + tt * tt * ex;
                    const ly = (1 - tt) * (1 - tt) * (cy + vy * (B - 1)) + 2 * (1 - tt) * tt * my + tt * tt * ey;
                    const dir = Math.atan2(ey - ly, ex - lx) + (j % 2 ? 0.9 : -0.9);
                    leaf(lx, ly, dir, (6 + rnd() * 3) * fs);
                }
                flower(ex, ey, (5 + rnd() * 1.6) * fs, rnd() * 6.28, petals[(k + Math.floor(rnd() * 3)) % 3]);
            }
            // a closed bud near the corner
            const ba = rnd() * Math.PI / 2;
            ctx.beginPath();
            ctx.ellipse(cx + ux * (B + 4 + Math.cos(ba) * 12 * fs) - 2 * fs, cy + vy * (B + 4 + Math.sin(ba) * 12 * fs) - 3 * fs, 4 * fs, 6 * fs);
            ctx.fillStyle = tint(petals[0], 0.8, 0.95);
            ctx.fill();
        }
        if (flowers) {
            // prefer the bottom corners, skipping any with a fossil
            const free = [2, 3, 0, 1].filter(i => !(fossils && (i === first || i === second)));
            for (const i of free.slice(0, 2)) {
                const c = corners[i];
                sprig(c[0] ? W : 0, c[1] ? H : 0, c[0] ? -1 : 1, c[1] ? -1 : 1);
            }
        }

        // Chips knocked out of the edge
        for (let i = 0; i < 7; i++) {
            const side = Math.floor(rnd() * 4), t = 0.12 + rnd() * 0.76, r = 2.5 + rnd() * 4;
            const cx = side === 0 ? t * W : side === 1 ? W : side === 2 ? t * W : 0;
            const cy = side === 0 ? 0 : side === 1 ? t * H : side === 2 ? H : t * H;
            ctx.beginPath();
            const n = 6;
            for (let k = 0; k <= n; k++) {
                const a = k / n * 2 * Math.PI, rr = r * (0.6 + rnd() * 0.6);
                k === 0 ? ctx.moveTo(cx + rr * Math.cos(a), cy + rr * Math.sin(a)) : ctx.lineTo(cx + rr * Math.cos(a), cy + rr * Math.sin(a));
            }
            ctx.closePath();
            ctx.fillStyle = tone(dark, 0.8, 0.85);
            ctx.fill();
        }

        // Outer edge
        roundRect(0.5, 0.5, W - 1, H - 1, R);
        ctx.strokeStyle = "rgba(0,0,0,0.6)";
        ctx.stroke();
        roundRect(1.5, 1.5, W - 3, H - 3, R - 1);
        ctx.strokeStyle = tone(light, 1, 0.18);
        ctx.stroke();
    }
}
