import QtQuick
import ".."

// Wood backing — dark stained walnut in a mitred frame with a gold inlay and brass corner brackets,
// lightly tinted toward the theme.
// Painted procedurally from `seed`, so the grain looks the same every time it redraws.
// Use: WoodBacking { anchors.fill: parent; visible: root.widgetBackground }        // rows of planks
//      WoodBacking { anchors.fill: parent; singleBoard: true; seed: 31 }           // one carved board
Canvas {
    id: wood

    // Fixed seed: the grain is identical on every redraw. Change it for a different piece of wood.
    property int seed: 20261106
    // false: rows of planks with seams and nails (quest board). true: one solid carved board (photo frame).
    property bool singleBoard: false

    opacity: 0.97
    antialiasing: true
    property color stain: Config.colors.base
    property real cornerRadius: Config.settings.defaultWindowRadius
    // Gold inlay and brass corner brackets take a hint of the theme's accent color.
    property color metal: Config.colors.accent
    // Carved frame ornaments: a flowering vine with brass ammonite medallions at the middle of each side.
    property bool ornaments: true
    // Picture-frame options: a wider frame, shaded like a moulding profile, with nothing painted inside.
    property real frameWidth: 17
    property bool moulding: false
    property bool paintInner: true
    onFrameWidthChanged: requestPaint()
    onMouldingChanged: requestPaint()
    onPaintInnerChanged: requestPaint()
    property real flowerSize: 1.45   // scales the vine's flowers and leaves
    onFlowerSizeChanged: requestPaint()
    onOrnamentsChanged: requestPaint()
    onMetalChanged: requestPaint()
    onStainChanged: requestPaint()
    onSeedChanged: requestPaint()
    onSingleBoardChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    onPaint: {
        const ctx = getContext("2d");
        const W = width, H = height;
        ctx.reset();
        if (W < 40 || H < 40)
            return;

        let sd = seed;
        const rnd = () => { sd = (sd * 16807) % 2147483647; return (sd - 1) / 2147483646; };
        const st = [stain.r * 255, stain.g * 255, stain.b * 255];
        // walnut tones mixed 18% toward the theme's base color
        const tone = (c, k, a) => {
            const v = c.map((x, i) => Math.max(0, Math.min(255, Math.round((x + (st[i] - x) * 0.18) * k))));
            return `rgba(${v[0]},${v[1]},${v[2]},${a === undefined ? 1 : a})`;
        };
        const plank = [110, 70, 40], trim = [40, 23, 11], grainDark = [36, 20, 9], grainLight = [176, 128, 82];
        const plankC = [108, 68, 38], darkC = [34, 18, 8], lightC = [184, 136, 88];
        const R = Math.max(2, cornerRadius), F = frameWidth;

        function roundRect(x, y, w, h, r) {
            ctx.beginPath();
            ctx.moveTo(x + r, y);
            ctx.arcTo(x + w, y, x + w, y + h, r);
            ctx.arcTo(x + w, y + h, x, y + h, r);
            ctx.arcTo(x, y + h, x, y, r);
            ctx.arcTo(x, y, x + w, y, r);
            ctx.closePath();
        }
        // ── Realistic board: paints one board in (x, y, w, h) with the grain running along x ──
        // detail: 1 = full (planks), 0 = simple (frame strips)
        function board(x, y, w, h, k, detail) {
            // 1. colour streaks along the length of the board
            const lg = ctx.createLinearGradient(x, 0, x + w, 0);
            const stops = 6 + Math.floor(rnd() * 5);
            for (let i = 0; i <= stops; i++)
                lg.addColorStop(i / stops, tone(plankC, k * (0.88 + rnd() * 0.2)));
            ctx.fillStyle = lg;
            ctx.fillRect(x, y, w, h);
            // rounded-edge shading across the board
            const sg = ctx.createLinearGradient(0, y, 0, y + h);
            sg.addColorStop(0, "rgba(255,230,190,0.07)");
            sg.addColorStop(0.15, "rgba(0,0,0,0)");
            sg.addColorStop(0.8, "rgba(0,0,0,0.05)");
            sg.addColorStop(1, "rgba(0,0,0,0.22)");
            ctx.fillStyle = sg;
            ctx.fillRect(x, y, w, h);

            // knots first, so the grain can flow around them
            const knots = [];
            if (detail && w > 160 && rnd() < 0.5)
                knots.push({ x: x + 50 + rnd() * (w - 100), y: y + h * (0.3 + rnd() * 0.4), rx: 9 + rnd() * 9, ry: 4 + rnd() * 3.5 });
            const defl = (t, yy) => {
                let d = 0;
                for (const kn of knots) {
                    const dx = (t - kn.x) / (kn.rx * 4), dy = (yy - kn.y) / (kn.ry * 3.2);
                    d += (yy >= kn.y ? 1 : -1) * kn.ry * 2.6 * Math.exp(-(dx * dx + dy * dy));
                }
                return d;
            };
            const step = 3;
            const line = (yBase, amp, f, ph, fn) => {
                ctx.beginPath();
                for (let t = x; t <= x + w + step; t += step) {
                    const yy = yBase + amp * Math.sin((t - x) * f + ph) + 0.6 * Math.sin((t - x) * f * 4.3 + ph * 1.7);
                    const py = (fn ? fn(t, yy) : yy) + defl(t, yy);
                    t === x ? ctx.moveTo(t, py) : ctx.lineTo(t, py);
                }
                ctx.stroke();
            };

            // 2. soft wide bands (latewood/earlywood figure)
            const bands = detail ? 10 + Math.floor(rnd() * 6) : 3;
            for (let i = 0; i < bands; i++) {
                ctx.strokeStyle = rnd() < 0.5 ? tone(darkC, 1, 0.05 + rnd() * 0.07) : tone(lightC, 1, 0.04 + rnd() * 0.05);
                ctx.lineWidth = 3 + rnd() * (h * 0.12);
                line(y + rnd() * h, 1 + rnd() * 3, 0.002 + rnd() * 0.006, rnd() * 6.28);
            }

            // 3. cathedral figure: nested pointed arches where the saw cut across the growth rings
            if (detail && w > 120 && rnd() < 0.75) {
                const cy = y + h * (0.35 + rnd() * 0.3), dir = rnd() < 0.5 ? 1 : -1;
                const px = x + w * (0.25 + rnd() * 0.5);
                const rings = 6 + Math.floor(rnd() * 5), sp = h / (2 * rings + 3);
                for (let i = 0; i < rings; i++) {
                    const d = (i + 0.8) * sp * (0.85 + rnd() * 0.3);
                    const tip = px + dir * i * (10 + rnd() * 10), L = 50 + i * (18 + rnd() * 10);
                    const wob = rnd() * 6.28;
                    for (const side of [-1, 1]) {
                        ctx.strokeStyle = tone(darkC, 1, 0.32 + rnd() * 0.25);
                        ctx.lineWidth = 0.8 + rnd() * 1.2;
                        ctx.beginPath();
                        let started = false;
                        for (let t = x; t <= x + w + step; t += step) {
                            const u = dir > 0 ? (tip - t) : (t - tip);
                            if (u < 0)
                                continue;
                            const taper = Math.sqrt(Math.min(1, u / L));
                            const yy = cy + side * d * taper + 0.8 * Math.sin(t * 0.05 + wob);
                            const py = yy + defl(t, yy);
                            started ? ctx.lineTo(t, py) : ctx.moveTo(t, py);
                            started = true;
                        }
                        ctx.stroke();
                    }
                }
            }

            // 4. fine straight grain with uneven ring spacing
            const lines = detail ? Math.round(h / 3.2) : Math.round(h / 4);
            let yy = y + rnd() * 3;
            for (let i = 0; i < lines && yy < y + h; i++) {
                const light = rnd() < 0.3;
                ctx.strokeStyle = light ? tone(lightC, 1, 0.07 + rnd() * 0.1) : tone(darkC, 1, 0.12 + rnd() * 0.26);
                ctx.lineWidth = 0.4 + rnd() * (rnd() < 0.15 ? 1.6 : 0.8);
                line(yy, 0.5 + rnd() * 2.2, 0.003 + rnd() * 0.01, rnd() * 6.28);
                yy += 1.2 + rnd() * rnd() * 7;
            }

            // 5. pores: tiny dashes running with the grain
            const pores = Math.round(w * h / (detail ? 55 : 90));
            ctx.lineWidth = 0.7;
            for (let i = 0; i < pores; i++) {
                const t = x + rnd() * w, py = y + rnd() * h, l = 1.2 + rnd() * 3.5;
                ctx.strokeStyle = tone(darkC, 0.8, 0.12 + rnd() * 0.22);
                ctx.beginPath();
                ctx.moveTo(t, py + defl(t, py));
                ctx.lineTo(t + l, py + defl(t + l, py));
                ctx.stroke();
            }

            // 6. the knots themselves: dark heart, tight rings, a soft halo and a hairline check
            for (const kn of knots) {
                const halo = ctx.createRadialGradient(kn.x, kn.y, 0, kn.x, kn.y, kn.rx * 2.6);
                halo.addColorStop(0, tone(darkC, 1, 0.35));
                halo.addColorStop(1, tone(darkC, 1, 0));
                ctx.fillStyle = halo;
                ctx.fillRect(kn.x - kn.rx * 2.6, kn.y - kn.rx * 2.6, kn.rx * 5.2, kn.rx * 5.2);
                for (let r = 5; r >= 1; r--) {
                    ctx.beginPath();
                    ctx.ellipse(kn.x - kn.rx * r / 5, kn.y - kn.ry * r / 5, kn.rx * 2 * r / 5, kn.ry * 2 * r / 5);
                    ctx.strokeStyle = tone(darkC, 0.9, 0.35 + 0.08 * (5 - r));
                    ctx.lineWidth = 0.9;
                    ctx.stroke();
                }
                ctx.beginPath();
                ctx.ellipse(kn.x - kn.rx * 0.35, kn.y - kn.ry * 0.35, kn.rx * 0.7, kn.ry * 0.7);
                ctx.fillStyle = tone(darkC, 0.55, 0.9);
                ctx.fill();
                ctx.beginPath();
                ctx.moveTo(kn.x, kn.y);
                ctx.lineTo(kn.x + kn.rx * (0.6 + rnd()), kn.y + (rnd() - 0.5) * kn.ry);
                ctx.strokeStyle = tone(darkC, 0.4, 0.7);
                ctx.lineWidth = 0.6;
                ctx.stroke();
            }
        }
        function nail(x, y) {
            const g = ctx.createRadialGradient(x - 0.8, y - 0.8, 0.3, x, y, 3.2);
            g.addColorStop(0, "rgba(200,196,186,1)");
            g.addColorStop(0.45, "rgba(110,104,96,1)");
            g.addColorStop(1, "rgba(30,26,22,1)");
            ctx.beginPath();
            ctx.arc(x, y, 3.2, 0, 2 * Math.PI);
            ctx.fillStyle = g;
            ctx.fill();
            ctx.beginPath();
            ctx.arc(x + 0.6, y + 0.9, 4.2, 0, 2 * Math.PI);
            ctx.strokeStyle = "rgba(0,0,0,0.25)";
            ctx.lineWidth = 1;
            ctx.stroke();
        }

        // Frame trim
        roundRect(0.5, 0.5, W - 1, H - 1, R);
        ctx.fillStyle = tone(trim, 1);
        ctx.fill();
        ctx.save();
        ctx.clip();
        const tk = moulding ? 0.8 : 0.42;   // picture-frame moulding uses lighter walnut so its profile shows
        board(0, 0, W, F, tk, 0);
        board(0, H - F, W, F, tk * 0.95, 0);
        for (const sx of [0, W - F]) {
            ctx.save();
            ctx.translate(sx + F, 0);
            ctx.rotate(Math.PI / 2);
            board(0, 0, H, F, tk * 0.95, 0);
            ctx.restore();
        }
        ctx.restore();
        // Moulding profile: outer lip, rounded bead, cove, flat, and a step down at the inner edge.
        // Each side is lit for light from the top-left, so the mitred corners read as real joints.
        if (moulding) {
            const shade = v => v >= 0 ? `rgba(255,236,200,${Math.min(0.6, v)})` : `rgba(0,0,0,${Math.min(0.7, -v)})`;
            const profile = [[0, -0.5, 0], [0.06, 0.02, 0.3], [0.16, 0.14, 0.26], [0.3, -0.05, 0.08], [0.42, -0.38, 0.1],
                             [0.55, -0.05, 0.02], [0.72, 0.04, 0.08], [0.86, 0, 0.02], [0.92, -0.35, 0], [1, -0.55, 0]];
            const sides = [
                { lf: 1, poly: [[0, 0], [W, 0], [W - F, F], [F, F]], g: [0, 0, 0, F] },
                { lf: 0.75, poly: [[0, 0], [F, F], [F, H - F], [0, H]], g: [0, 0, F, 0] },
                { lf: -0.45, poly: [[W, 0], [W, H], [W - F, H - F], [W - F, F]], g: [W, 0, W - F, 0] },
                { lf: -0.75, poly: [[0, H], [F, H - F], [W - F, H - F], [W, H]], g: [0, H, 0, H - F] }
            ];
            ctx.save();
            roundRect(0.5, 0.5, W - 1, H - 1, R);
            ctx.clip();
            for (const sd2 of sides) {
                const lg = ctx.createLinearGradient(sd2.g[0], sd2.g[1], sd2.g[2], sd2.g[3]);
                for (const p of profile)
                    lg.addColorStop(p[0], shade(p[1] + p[2] * sd2.lf - (sd2.lf < 0 ? 0.06 : 0)));
                ctx.beginPath();
                sd2.poly.forEach((q, i) => i === 0 ? ctx.moveTo(q[0], q[1]) : ctx.lineTo(q[0], q[1]));
                ctx.closePath();
                ctx.fillStyle = lg;
                ctx.fill();
            }
            ctx.restore();
        }
        // mitred corner seams
        ctx.strokeStyle = tone(grainDark, 0.8, 0.6);
        ctx.lineWidth = 1;
        ctx.beginPath();
        ctx.moveTo(3, 3); ctx.lineTo(F, F);
        ctx.moveTo(W - 3, 3); ctx.lineTo(W - F, F);
        ctx.moveTo(3, H - 3); ctx.lineTo(F, H - F);
        ctx.moveTo(W - 3, H - 3); ctx.lineTo(W - F, H - F);
        ctx.stroke();
        // outer bevel
        roundRect(1.5, 1.5, W - 3, H - 3, R - 1);
        ctx.strokeStyle = tone(grainLight, 1, 0.22);
        ctx.lineWidth = 1;
        ctx.stroke();
        roundRect(0.5, 0.5, W - 1, H - 1, R);
        ctx.strokeStyle = "rgba(0,0,0,0.55)";
        ctx.stroke();

        // Planks (skipped when something else, like a picture mat, fills the inside)
        const x0 = F, y0 = F, w = W - 2 * F, h = H - 2 * F;
        if (paintInner) {
        const rows = singleBoard ? 1 : Math.max(1, Math.round(h / 96)), ph = h / rows;
        ctx.save();
        ctx.beginPath();
        ctx.rect(x0, y0, w, h);
        ctx.clip();
        for (let r = 0; r < rows; r++) {
            const y = y0 + r * ph;
            const joints = [x0];
            if (w > 260 && !singleBoard) {
                // keep joints near the ends so seams don't cut through text in the middle
                const j = x0 + w * (r % 2 === 0 ? 0.8 + 0.12 * rnd() : 0.08 + 0.12 * rnd());  // alternate sides
                joints.push(j);
            }
            joints.push(x0 + w);
            for (let b = 0; b < joints.length - 1; b++) {
                const bx = joints[b], bw = joints[b + 1] - bx;
                ctx.save();
                ctx.beginPath();
                ctx.rect(bx, y, bw, ph);
                ctx.clip();
                board(bx, y, bw, ph, 0.8 + rnd() * 0.34, 1);
                ctx.restore();
                // butt joint
                if (b > 0) {
                    ctx.fillStyle = "rgba(0,0,0,0.55)";
                    ctx.fillRect(bx - 1, y, 2, ph);
                    ctx.fillStyle = tone(grainLight, 1, 0.15);
                    ctx.fillRect(bx + 1, y, 1, ph);
                }
            }
            // seam between rows
            if (r > 0) {
                ctx.fillStyle = "rgba(0,0,0,0.6)";
                ctx.fillRect(x0, y - 1, w, 2);
                ctx.fillStyle = tone(grainLight, 1, 0.16);
                ctx.fillRect(x0, y + 1, w, 1);
            }
        }
        // a faint varnish sheen catching the light diagonally
        const sh = ctx.createLinearGradient(x0, y0, x0 + w * 0.7, y0 + h);
        sh.addColorStop(0, "rgba(255,240,210,0)");
        sh.addColorStop(0.42, "rgba(255,240,210,0.05)");
        sh.addColorStop(0.5, "rgba(255,240,210,0.08)");
        sh.addColorStop(0.58, "rgba(255,240,210,0.05)");
        sh.addColorStop(1, "rgba(255,240,210,0)");
        ctx.fillStyle = sh;
        ctx.fillRect(x0, y0, w, h);
        // soft vignette so text in the middle sits on slightly darker wood
        const vg = ctx.createRadialGradient(W / 2, H / 2, Math.min(w, h) * 0.2, W / 2, H / 2, Math.max(w, h) * 0.75);
        vg.addColorStop(0, "rgba(0,0,0,0.12)");
        vg.addColorStop(1, "rgba(0,0,0,0.42)");
        ctx.fillStyle = vg;
        ctx.fillRect(x0, y0, w, h);
        // inner shadow where the planks meet the frame
        ctx.strokeStyle = "rgba(0,0,0,0.5)";
        ctx.lineWidth = 3;
        ctx.strokeRect(x0 + 1, y0 + 1, w - 2, h - 2);
        ctx.restore();
        ctx.strokeStyle = tone(grainLight, 1, 0.18);
        ctx.lineWidth = 1;
        ctx.strokeRect(x0 - 0.5, y0 - 0.5, w + 1, h + 1);

        }
        // Gold inlay running round the frame, set in a dark groove
        const mt = [metal.r * 255, metal.g * 255, metal.b * 255];
        const gold = (k, a) => {
            const base = [196, 156, 84];
            const v = base.map((x, i) => Math.max(0, Math.min(255, Math.round((x + (mt[i] - x) * 0.35) * k))));
            return `rgba(${v[0]},${v[1]},${v[2]},${a === undefined ? 1 : a})`;
        };
        const gi = F - 5;
        ctx.strokeStyle = "rgba(0,0,0,0.55)";
        ctx.lineWidth = 3;
        ctx.strokeRect(gi + 0.5, gi + 0.5, W - 2 * gi - 1, H - 2 * gi - 1);
        ctx.strokeStyle = gold(1, 0.9);
        ctx.lineWidth = 1.2;
        ctx.strokeRect(gi + 0.5, gi + 0.5, W - 2 * gi - 1, H - 2 * gi - 1);

        // ── Ornaments: flowering vine along the frame, ammonite medallions mid-side ──
        const L0 = Math.min(38, Math.min(W, H) * 0.18);   // bracket arm length (matches below)
        const medR = Math.min(15, F * 0.9);
        const mix3 = (c, k, a) => {
            const v = c.map((x, i) => Math.max(0, Math.min(255, Math.round((x + (mt[i] - x) * 0.3) * k))));
            return `rgba(${v[0]},${v[1]},${v[2]},${a === undefined ? 1 : a})`;
        };
        const petal = [236, 150, 150], leaf = [112, 134, 72];

        function flower(x, y, r, rot) {
            for (let i = 0; i < 5; i++) {
                const a = rot + i * 2 * Math.PI / 5;
                ctx.save();
                ctx.translate(x + Math.cos(a) * r * 0.55, y + Math.sin(a) * r * 0.55);
                ctx.rotate(a);
                ctx.beginPath();
                ctx.ellipse(-r * 0.55, -r * 0.33, r * 1.1, r * 0.66);
                ctx.fillStyle = mix3(petal, i % 2 ? 0.92 : 1, 0.95);
                ctx.fill();
                ctx.strokeStyle = "rgba(40,16,10,0.55)";
                ctx.lineWidth = 0.6;
                ctx.stroke();
                ctx.restore();
            }
            ctx.beginPath();
            ctx.arc(x, y, r * 0.38, 0, 2 * Math.PI);
            ctx.fillStyle = gold(1.2);
            ctx.fill();
            ctx.strokeStyle = "rgba(40,20,4,0.7)";
            ctx.lineWidth = 0.6;
            ctx.stroke();
        }
        function leafAt(x, y, ang, len) {
            ctx.save();
            ctx.translate(x, y);
            ctx.rotate(ang);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.quadraticCurveTo(len * 0.5, -len * 0.42, len, 0);
            ctx.quadraticCurveTo(len * 0.5, len * 0.42, 0, 0);
            ctx.fillStyle = mix3(leaf, 0.9 + rnd() * 0.25, 0.9);
            ctx.fill();
            ctx.strokeStyle = "rgba(10,20,4,0.5)";
            ctx.lineWidth = 0.5;
            ctx.stroke();
            ctx.restore();
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
        let fossilFlip = 0;   // vines alternate brass ammonites and trilobites
        // A vine from (x1,y1) to (x2,y2) along the middle of the frame
        function vine(x1, y1, x2, y2) {
            const dx = x2 - x1, dy = y2 - y1, len = Math.hypot(dx, dy);
            if (len < 24)
                return;
            const ux = dx / len, uy = dy / len, nx = -uy, ny = ux;
            const amp = F * 0.16, wl = 34;
            const at = t => {
                const o = amp * Math.sin(t / wl * 2 * Math.PI);
                return [x1 + ux * t + nx * o, y1 + uy * t + ny * o];
            };
            ctx.beginPath();
            for (let t = 0; t <= len; t += 2) {
                const p = at(t);
                t === 0 ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]);
            }
            ctx.strokeStyle = gold(0.85, 0.85);
            ctx.lineWidth = 1.1;
            ctx.stroke();
            const base = Math.atan2(uy, ux);
            for (let t = 9; t < len - 6; t += wl / 2) {
                const p = at(t), side = (Math.round(t / (wl / 2)) % 2) ? 1 : -1;
                leafAt(p[0], p[1], base + side * 0.9, F * 0.42 * Math.sqrt(flowerSize));
            }
            const n = Math.max(1, Math.round(len / (40 + 12 * flowerSize)));
            for (let i = 0; i < n; i++) {
                const t = len * (i + 0.5) / n, p = at(t);
                flower(p[0], p[1], F * 0.29 * flowerSize, rnd() * 6.28);
            }
            // little brass ammonites strung between the flowers
            for (let i = 1; i < n; i++) {
                const p = at(len * i / n);
                if (fossilFlip++ % 3 !== 1)
                    trilobite(p[0], p[1], Math.max(18, F * 1.35), base + Math.PI / 2 + (rnd() < 0.5 ? 0 : Math.PI) + (rnd() - 0.5) * 0.4, gold(1.0),
                              [{ "o": -0.4, "col": gold(1.45, 0.85), "w": 0.8 }, { "o": 0, "col": "rgba(30,18,4,0.9)", "w": 0.9 }]);
                else
                    ammonite(p[0], p[1], Math.max(6.5, F * 0.47), rnd() * 6.28);
            }
        }
        // Brass medallion engraved with an ammonite: a logarithmic spiral with ribs across each whorl
        function ammonite(cx, cy, R0, rot) {
            const g = ctx.createRadialGradient(cx - R0 * 0.35, cy - R0 * 0.35, R0 * 0.1, cx, cy, R0);
            g.addColorStop(0, gold(1.3));
            g.addColorStop(0.6, gold(0.95));
            g.addColorStop(1, gold(0.6));
            ctx.beginPath();
            ctx.arc(cx, cy, R0, 0, 2 * Math.PI);
            ctx.fillStyle = g;
            ctx.fill();
            ctx.strokeStyle = "rgba(20,12,4,0.9)";
            ctx.lineWidth = 1;
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(cx, cy, R0 - 2, 0, 2 * Math.PI);
            ctx.strokeStyle = gold(0.5, 0.7);
            ctx.lineWidth = 0.7;
            ctx.stroke();

            const rO = R0 - 3.2, b = Math.log(2) / (2 * Math.PI);   // each whorl doubles in size
            const tMax = 3 * 2 * Math.PI;
            const r = th => rO * Math.exp(b * (th - tMax));
            const pt = (th, rr) => [cx + rr * Math.cos(th + rot), cy + rr * Math.sin(th + rot)];
            // ribs (septa) across each whorl
            ctx.strokeStyle = gold(0.42, 0.85);
            ctx.lineWidth = 0.55;
            for (let th = 2 * Math.PI; th <= tMax; th += 0.32) {
                const p1 = pt(th, r(th)), p2 = pt(th, r(th - 2 * Math.PI));
                ctx.beginPath();
                ctx.moveTo(p1[0], p1[1]);
                ctx.lineTo(p2[0], p2[1]);
                ctx.stroke();
            }
            // the spiral itself
            ctx.beginPath();
            for (let th = 0.6; th <= tMax; th += 0.08) {
                const p = pt(th, r(th));
                th === 0.6 ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]);
            }
            ctx.strokeStyle = "rgba(30,18,4,0.95)";
            ctx.lineWidth = 1.1;
            ctx.stroke();
            // a glint on the shell
            ctx.beginPath();
            ctx.arc(cx - R0 * 0.3, cy - R0 * 0.38, R0 * 0.18, 0, 2 * Math.PI);
            ctx.fillStyle = "rgba(255,248,220,0.35)";
            ctx.fill();
        }

        if (ornaments) {
            const c = F / 2, sideR = Math.min(F / 2 + 0.5, 13), gap = medR + 10 + 8 * flowerSize, sideGap = sideR + 10 + 8 * flowerSize, e = L0 + 11;
            const showSides = H > 2 * (e + sideGap) + 20;
            // top and bottom: bracket → medallion → bracket
            vine(e, c, W / 2 - gap, c);
            vine(W - e, c, W / 2 + gap, c);
            vine(e, H - c, W / 2 - gap, H - c);
            vine(W - e, H - c, W / 2 + gap, H - c);
            // left and right
            if (showSides) {
                vine(c, e, c, H / 2 - sideGap);
                vine(c, H - e, c, H / 2 + sideGap);
                vine(W - c, e, W - c, H / 2 - sideGap);
                vine(W - c, H - e, W - c, H / 2 + sideGap);
            } else {
                vine(c, e, c, H - e);
                vine(W - c, e, W - c, H - e);
            }
            // a flower on each side of every medallion
            const fr = F * 0.34 * flowerSize;
            for (const [x, y] of [[W / 2 - medR - 3 - 5 * flowerSize, c], [W / 2 + medR + 3 + 5 * flowerSize, c], [W / 2 - medR - 3 - 5 * flowerSize, H - c], [W / 2 + medR + 3 + 5 * flowerSize, H - c]])
                flower(x, y, fr, rnd() * 6.28);
            if (showSides)
                for (const [x, y] of [[c, H / 2 - sideR - 3 - 5 * flowerSize], [c, H / 2 + sideR + 3 + 5 * flowerSize], [W - c, H / 2 - sideR - 3 - 5 * flowerSize], [W - c, H / 2 + sideR + 3 + 5 * flowerSize]])
                    flower(x, y, fr, rnd() * 6.28);
            ammonite(W / 2, c, medR, 0.3);
            ammonite(W / 2, H - c, medR, 2.4);
            if (showSides) {
                ammonite(c, H / 2, sideR, 4.1);
                ammonite(W - c, H / 2, sideR, 5.6);
            }
        }

        // Brass corner brackets with pointed arms and rivets
        const t = Math.min(F - 2, 15), L = Math.min(38, Math.min(W, H) * 0.18);
        ctx.save();
        roundRect(0.5, 0.5, W - 1, H - 1, R);
        ctx.clip();
        const corners = [[0, 0, 0], [W, 0, Math.PI / 2], [W, H, Math.PI], [0, H, Math.PI * 1.5]];
        for (const c of corners) {
            ctx.save();
            ctx.translate(c[0], c[1]);
            ctx.rotate(c[2]);
            ctx.beginPath();
            ctx.moveTo(0, 0);
            ctx.lineTo(L, 0);
            ctx.lineTo(L + 7, t / 2);
            ctx.lineTo(L, t);
            ctx.lineTo(t, t);
            ctx.lineTo(t, L);
            ctx.lineTo(t / 2, L + 7);
            ctx.lineTo(0, L);
            ctx.closePath();
            const bg = ctx.createLinearGradient(0, 0, L * 0.8, L * 0.8);
            bg.addColorStop(0, gold(1.25));
            bg.addColorStop(0.45, gold(0.95));
            bg.addColorStop(1, gold(0.55));
            ctx.fillStyle = bg;
            ctx.fill();
            ctx.strokeStyle = "rgba(20,12,4,0.85)";
            ctx.lineWidth = 1;
            ctx.stroke();
            // engraved line following the inner edge
            ctx.beginPath();
            ctx.moveTo(L - 2, t - 3); ctx.lineTo(t - 3, t - 3); ctx.lineTo(t - 3, L - 2);
            ctx.strokeStyle = gold(0.45, 0.8);
            ctx.stroke();
            ammonite(t / 2 + 1, t / 2 + 1, t / 2 + 1.5, c[2] + 0.8);   // ammonite boss on each corner
            nail(L - 3, t / 2);
            nail(t / 2, L - 3);
            ctx.restore();
        }
        ctx.restore();
    }
}
