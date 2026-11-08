import QtQuick
import ".."

// Parchment note — an aged scrap of paper with torn edges, tea stains and foxing,
// held to the board by a pushpin. Painted procedurally from `key` (e.g. the quest title),
// so each note keeps its own look across redraws. The canvas reaches `margin` px past the
// paper on every side to leave room for the drop shadow.
// Use: ParchmentNote { anchors.fill: parent; anchors.margins: -margin; key: title }
Canvas {
    id: note

    property string key: ""
    property bool pinned: true
    property real pinX: 10          // pin position, from the paper's left edge
    readonly property real margin: 5
    property color stain: Config.colors.accent   // a faint hint of the theme in the paper

    antialiasing: true
    onKeyChanged: requestPaint()
    onPinnedChanged: requestPaint()
    onStainChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()

    function hash(s) {
        let h = 2166136261;
        for (let i = 0; i < s.length; i++)
            h = Math.imul(h ^ s.charCodeAt(i), 16777619) >>> 0;
        return (h % 2147483646) + 1;
    }

    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        const m = margin, W = width - 2 * m, H = height - 2 * m;
        if (W < 20 || H < 12)
            return;

        let sd = hash(key || "note");
        const rnd = () => { sd = (sd * 16807) % 2147483647; return (sd - 1) / 2147483646; };
        const st = [stain.r * 255, stain.g * 255, stain.b * 255];
        const paper = (c, k, a) => {
            const v = c.map((x, i) => Math.max(0, Math.min(255, Math.round((x + (st[i] - x) * 0.07) * k))));
            return `rgba(${v[0]},${v[1]},${v[2]},${a === undefined ? 1 : a})`;
        };
        const cream = [232, 212, 168], tea = [150, 104, 52], burnt = [92, 56, 22];

        // Torn outline: walk round the edges with small random bites taken out
        const pts = [];
        const edge = (x0, y0, x1, y1, inX, inY) => {
            const len = Math.hypot(x1 - x0, y1 - y0), n = Math.max(2, Math.round(len / 5));
            for (let i = 0; i < n; i++) {
                const t = i / n, bite = rnd() < 0.08 ? 1.5 + rnd() * 2.2 : rnd() * 1.3;
                pts.push([m + x0 + (x1 - x0) * t + inX * bite, m + y0 + (y1 - y0) * t + inY * bite]);
            }
        };
        const cut = 1.5 + rnd() * 3; // a slightly dog-eared corner
        edge(cut, 0, W, 0, 0, 1);
        edge(W, 0, W, H, -1, 0);
        edge(W, H, 0, H, 0, -1);
        edge(0, H, 0, cut, 1, 0);
        const outline = () => {
            ctx.beginPath();
            pts.forEach((p, i) => i === 0 ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]));
            ctx.closePath();
        };

        // Paper with a soft shadow on the board
        outline();
        const g = ctx.createLinearGradient(m, m, m + W * 0.4, m + H);
        g.addColorStop(0, paper(cream, 1.03));
        g.addColorStop(0.6, paper(cream, 0.97));
        g.addColorStop(1, paper(cream, 0.9));
        ctx.fillStyle = g;
        ctx.shadowColor = "rgba(0,0,0,0.55)";
        ctx.shadowBlur = 5;
        ctx.shadowOffsetX = 1.5;
        ctx.shadowOffsetY = 2.5;
        ctx.fill();
        ctx.shadowColor = "transparent";
        ctx.shadowBlur = 0;
        ctx.shadowOffsetX = 0;
        ctx.shadowOffsetY = 0;

        ctx.save();
        outline();
        ctx.clip();
        // Tea stains and age blotches
        for (let i = 0; i < 4 + Math.floor(rnd() * 3); i++) {
            const x = m + rnd() * W, y = m + rnd() * H, r = 10 + rnd() * Math.max(30, H * 1.2);
            const sg = ctx.createRadialGradient(x, y, r * 0.2, x, y, r);
            sg.addColorStop(0, paper(tea, 1, 0.05 + rnd() * 0.06));
            sg.addColorStop(0.85, paper(tea, 1, 0.07 + rnd() * 0.05));
            sg.addColorStop(1, paper(tea, 1, 0));
            ctx.fillStyle = sg;
            ctx.fillRect(x - r, y - r, 2 * r, 2 * r);
        }
        // Foxing: tiny brown specks
        for (let i = 0; i < Math.round(W * H / 220); i++) {
            ctx.beginPath();
            ctx.arc(m + rnd() * W, m + rnd() * H, 0.4 + rnd() * 1.1, 0, 2 * Math.PI);
            ctx.fillStyle = paper(tea, 0.9, 0.12 + rnd() * 0.2);
            ctx.fill();
        }
        // Paper fibres
        for (let i = 0; i < Math.round(W / 40); i++) {
            const x = m + rnd() * W, y = m + rnd() * H, l = 6 + rnd() * 18, a = (rnd() - 0.5) * 0.6;
            ctx.beginPath();
            ctx.moveTo(x, y);
            ctx.lineTo(x + Math.cos(a) * l, y + Math.sin(a) * l);
            ctx.strokeStyle = paper(tea, 1, 0.08);
            ctx.lineWidth = 0.6;
            ctx.stroke();
        }
        // Darkened, slightly burnt edges
        for (const [w, a] of [[10, 0.05], [6, 0.07], [3, 0.12]]) {
            outline();
            ctx.strokeStyle = paper(burnt, 1, a);
            ctx.lineWidth = w;
            ctx.stroke();
        }
        ctx.restore();
        outline();
        ctx.strokeStyle = paper(burnt, 0.8, 0.55);
        ctx.lineWidth = 0.8;
        ctx.stroke();

        // Pushpin: shadow on the paper, a domed red head with a highlight
        if (pinned) {
            const px = m + pinX, py = m + H / 2, r = 4.6;
            ctx.beginPath();
            ctx.ellipse(px - r + 2, py - r * 0.8 + 3, r * 2.1, r * 1.6);
            ctx.fillStyle = "rgba(40,20,5,0.35)";
            ctx.fill();
            const pg = ctx.createRadialGradient(px - 1.5, py - 1.8, 0.4, px, py, r);
            pg.addColorStop(0, "rgba(255,170,150,1)");
            pg.addColorStop(0.35, "rgba(196,52,40,1)");
            pg.addColorStop(1, "rgba(98,18,12,1)");
            ctx.beginPath();
            ctx.arc(px, py, r, 0, 2 * Math.PI);
            ctx.fillStyle = pg;
            ctx.fill();
            ctx.strokeStyle = "rgba(50,8,4,0.8)";
            ctx.lineWidth = 0.7;
            ctx.stroke();
            ctx.beginPath();
            ctx.arc(px - 1.6, py - 1.8, 1.1, 0, 2 * Math.PI);
            ctx.fillStyle = "rgba(255,240,230,0.8)";
            ctx.fill();
        }
    }
}
