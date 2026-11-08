import Quickshell
import QtQuick
import ".."

// Sun Tracker ("Cursus Solis") — where the sun is in the sky right now, and its path through the day.
// The sky window plots the sun's altitude from midnight to midnight: the gold arc is the daylight
// part of its path, the dashed line is its path below the horizon, and the glowing disc is the sun
// now. The sky's colors follow the real sun (night, dawn glow, day).
// Location: the weather city in settings (geocoded once through Open-Meteo, no key needed); falls
// back to San Bernardino if offline. Sun position is calculated locally (NOAA approximation).
// Wooden planks in a nailed frame, like the Quest Board (see WoodBacking.qml).
// Drag by any empty space to move; the position is saved to widgets.json.
Rectangle {
    id: root

    property bool widgetBackground: true
    property var widgetData: null

    width: 440
    height: content.implicitHeight + 46
    color: "transparent"

    // ── Location ──
    property real lat: 34.1083
    property real lon: -117.2898
    property string placeName: "San Bernardino"
    readonly property string city: Config.settings.openWeatherMap ? Config.settings.openWeatherMap.city : ""
    onCityChanged: geocode()
    function geocode() {
        if (!city)
            return;
        const parts = city.split(",");
        const name = parts[0].trim();
        const country = parts.length > 1 ? parts[parts.length - 1].trim() : "";
        const asked = city;
        const xhr = new XMLHttpRequest();
        xhr.onreadystatechange = function () {
            // Settings load after startup, so an answer for the placeholder city can arrive late.
            if (xhr.readyState !== XMLHttpRequest.DONE || asked !== root.city)
                return;
            try {
                const p = JSON.parse(xhr.responseText).results[0];
                root.lat = p.latitude;
                root.lon = p.longitude;
                root.placeName = p.name;
                root.recompute();
            } catch (e) {
                console.warn("SunTracker: couldn't geocode \"" + root.city + "\", using " + root.placeName);
            }
        };
        xhr.open("GET", "https://geocoding-api.open-meteo.com/v1/search?count=1&name=" + encodeURIComponent(name) + (country.length === 2 ? "&countryCode=" + country : ""), true);
        xhr.send();
    }

    // ── Sun math ──
    readonly property real rad: Math.PI / 180
    // Returns { alt, az } in degrees for a Date at (lat, lon). Azimuth: 0 = north, 90 = east.
    function sunPos(d) {
        const n = d.getTime() / 86400000 + 2440587.5 - 2451545.0;
        const L = (280.460 + 0.9856474 * n) % 360;
        const g = ((357.528 + 0.9856003 * n) % 360) * rad;
        const lam = (L + 1.915 * Math.sin(g) + 0.020 * Math.sin(2 * g)) * rad;
        const eps = (23.439 - 0.0000004 * n) * rad;
        const ra = Math.atan2(Math.cos(eps) * Math.sin(lam), Math.cos(lam));
        const dec = Math.asin(Math.sin(eps) * Math.sin(lam));
        const gmst = ((18.697374558 + 24.06570982441908 * n) % 24 + 24) % 24;
        const ha = (gmst * 15 + lon) * rad - ra;
        const phi = lat * rad;
        const alt = Math.asin(Math.sin(phi) * Math.sin(dec) + Math.cos(phi) * Math.cos(dec) * Math.cos(ha));
        let az = Math.atan2(-Math.sin(ha), Math.tan(dec) * Math.cos(phi) - Math.sin(phi) * Math.cos(ha)) / rad;
        az = (az + 360) % 360;
        return { "alt": alt / rad, "az": az };
    }

    property date now: new Date()
    property var curve: []          // [{ h: hour of day 0..24, alt }]
    property real riseH: -1         // hours after local midnight, -1 = none today
    property real setH: -1
    property real noonH: 12
    property real noonAlt: 0
    property var sun: ({ "alt": 0, "az": 180 })
    property string dayKey: ""

    function recompute() {
        const midnight = new Date(now.getFullYear(), now.getMonth(), now.getDate());
        const pts = [];
        let best = -999, bestH = 12;
        for (let m = 0; m <= 24 * 60; m += 6) {
            const a = sunPos(new Date(midnight.getTime() + m * 60000)).alt;
            pts.push({ "h": m / 60, "alt": a });
            if (a > best) { best = a; bestH = m / 60; }
        }
        // Sunrise/sunset: where the sun's upper edge crosses the horizon (-0.833° with refraction).
        let rise = -1, set = -1;
        const H0 = -0.833;
        for (let i = 1; i < pts.length; i++) {
            const a0 = pts[i - 1].alt - H0, a1 = pts[i].alt - H0;
            if (a0 < 0 && a1 >= 0 && rise < 0)
                rise = pts[i - 1].h + (pts[i].h - pts[i - 1].h) * (-a0 / (a1 - a0));
            if (a0 >= 0 && a1 < 0)
                set = pts[i - 1].h + (pts[i].h - pts[i - 1].h) * (a0 / (a0 - a1));
        }
        curve = pts;
        riseH = rise;
        setH = set;
        noonH = bestH;
        noonAlt = best;
        dayKey = midnight.toDateString();
        tick();
    }
    function tick() {
        now = new Date();
        if (now.toDateString() !== dayKey && curve.length) {
            recompute();
            return;
        }
        sun = sunPos(now);
        sky.requestPaint();
    }
    readonly property real nowH: now.getHours() + now.getMinutes() / 60 + now.getSeconds() / 3600

    Timer {
        interval: 30000
        running: true
        repeat: true
        onTriggered: root.tick()
    }
    Component.onCompleted: { recompute(); geocode(); }

    // ── Formatting ──
    function fmtHour(h) {
        if (h < 0)
            return "—";
        const d = new Date(now.getFullYear(), now.getMonth(), now.getDate(), 0, Math.round(h * 60));
        return Qt.formatTime(d, Config.settings.militaryTimeClockFormat ? "hh:mm" : "h:mm AP");
    }
    function fmtSpan(hours) {
        const m = Math.max(0, Math.round(hours * 60));
        const h = Math.floor(m / 60);
        return h > 0 ? h + "h " + (m % 60) + "m" : (m % 60) + "m";
    }
    function direction(az) {
        const names = ["north", "north-east", "east", "south-east", "south", "south-west", "west", "north-west"];
        return names[Math.round(az / 45) % 8];
    }
    function status() {
        const a = Math.round(sun.alt);
        if (sun.alt > -0.833) {
            return "The sun stands " + a + "° high in the " + direction(sun.az);
        }
        return "The sun rests " + Math.abs(a) + "° below the " + direction(sun.az) + " horizon";
    }
    function countdown() {
        if (sun.alt > -0.833)
            return setH > nowH ? fmtSpan(setH - nowH) + " of light remain" : "";
        let until = -1;
        if (riseH > nowH)
            until = riseH - nowH;
        else if (riseH >= 0)
            until = 24 - nowH + riseH;   // tomorrow's sunrise is close enough to today's
        return until >= 0 ? "dawn in " + fmtSpan(until) : "";
    }
    function phaseName() {
        const a = sun.alt;
        if (a < -18) return "Nox · deep night";
        if (a < -6) return nowH < 12 ? "Antelucanum · before dawn" : "Crepusculum · dusk";
        if (a < 0) return nowH < 12 ? "Aurora · dawn" : "Vesper · twilight";
        if (a < 10) return nowH < 12 ? "Mane · sunrise glow" : "Occasus · golden hour";
        if (Math.abs(nowH - noonH) < 0.75) return "Meridies · high noon";
        return nowH < noonH ? "Mane · morning" : "Post meridiem · afternoon";
    }

    // ── Backing: planks in a nailed frame, like the Quest Board ──
    WoodBacking {
        anchors.fill: parent
        visible: root.widgetBackground
        seed: 1107
    }

    MouseArea {
        anchors.fill: parent
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.threshold: 4
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: (root.parent && root.parent.parent) ? root.parent.parent.width - root.width : 10000
        drag.maximumY: (root.parent && root.parent.parent) ? root.parent.parent.height - root.height : 10000
        onReleased: {
            const d = root.widgetData;
            if (!d)
                return;
            Config.updateWidget(d.monitorName, d.widgetId, d.widgetName, Math.round(root.x), Math.round(root.y), d.enableBackground, d.widgetType);
        }
    }

    readonly property color titleInk: Qt.lighter(Config.colors.accent, 1.12)
    readonly property color outline: "#e6140a04"

    Column {
        id: content
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 24
        spacing: 6

        // Heading on a hanging sign, like the Quest Board's
        Item {
            width: sky.width
            height: head.implicitHeight + 18
            Repeater {
                model: [-1, 1]
                delegate: Column {
                    required property var modelData
                    x: parent.width / 2 + modelData * (sign.width / 2 - 26) - width / 2
                    y: -14
                    spacing: -3
                    Repeater {
                        model: 2
                        delegate: Rectangle {
                            required property int index
                            width: index % 2 ? 4 : 9
                            height: 11
                            radius: 4.5
                            anchors.horizontalCenter: parent.horizontalCenter
                            color: "transparent"
                            border.width: 2.2
                            border.color: index % 2 ? "#9c7a36" : "#d4ae62"
                        }
                    }
                }
            }
            WoodBacking {
                id: sign
                anchors.horizontalCenter: parent.horizontalCenter
                y: 4
                width: Math.max(head.implicitWidth + 90, 280)
                height: head.implicitHeight + 14
                singleBoard: true
                ornaments: false
                cornerRadius: 6
                seed: 78
                visible: root.widgetBackground
            }
            Column {
                id: head
                anchors.horizontalCenter: parent.horizontalCenter
                y: 11
                spacing: 0
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: "Cursus Solis"
                    font.family: fontBoska.name
                    font.pixelSize: 34
                    font.weight: 600
                    color: root.titleInk
                    style: Text.Outline
                    styleColor: root.outline
                }
                Text {
                    anchors.horizontalCenter: parent.horizontalCenter
                    text: root.phaseName()
                    font.family: fontDominica.name
                    font.pixelSize: 15
                    color: Config.colors.textLight
                    style: Text.Outline
                    styleColor: root.outline
                }
            }
        }

        // ── The sky window ──
        Canvas {
            id: sky
            width: 380
            height: 160
            anchors.horizontalCenter: parent.horizontalCenter
            antialiasing: true
            onPaint: {
                const ctx = getContext("2d");
                const W = width, H = height;
                ctx.reset();
                const pts = root.curve;
                if (!pts.length)
                    return;

                const padX = 14, plotTop = 16, plotBot = H - 24;
                // Below-horizon altitudes are squashed so night doesn't take over the window.
                const squash = 0.35;
                const topAlt = Math.max(30, root.noonAlt) + 14;
                let minAlt = 0;
                for (const p of pts) minAlt = Math.min(minAlt, p.alt);
                const botAlt = minAlt * squash - 6;
                const X = h => padX + (W - 2 * padX) * h / 24;
                const Y = a => {
                    const v = a >= 0 ? a : a * squash;
                    return plotTop + (plotBot - plotTop) * (topAlt - v) / (topAlt - botAlt);
                };
                const hY = Y(0);
                const lerp = (a, b, t) => a.map((x, i) => Math.round(x + (b[i] - x) * Math.max(0, Math.min(1, t))));
                const rgb = (c, a) => `rgba(${c[0]},${c[1]},${c[2]},${a === undefined ? 1 : a})`;
                function rr(x, y, w, h, r) {
                    ctx.beginPath();
                    ctx.moveTo(x + r, y);
                    ctx.arcTo(x + w, y, x + w, y + h, r);
                    ctx.arcTo(x + w, y + h, x, y + h, r);
                    ctx.arcTo(x, y + h, x, y, r);
                    ctx.arcTo(x, y, x + w, y, r);
                    ctx.closePath();
                }

                // Sky colors from the real sun: night → twilight → golden → day.
                const alt = root.sun.alt;
                const night = [[10, 14, 36], [34, 40, 78]];
                const twi = [[48, 52, 102], [222, 128, 86]];
                const gold = [[92, 128, 176], [240, 196, 132]];
                const day = [[78, 128, 182], [190, 214, 228]];
                let top, bot;
                if (alt < -12) { top = night[0]; bot = night[1]; }
                else if (alt < -2) { const t = (alt + 12) / 10; top = lerp(night[0], twi[0], t); bot = lerp(night[1], twi[1], t); }
                else if (alt < 8) { const t = (alt + 2) / 10; top = lerp(twi[0], gold[0], t); bot = lerp(twi[1], gold[1], t); }
                else { const t = (alt - 8) / 14; top = lerp(gold[0], day[0], t); bot = lerp(gold[1], day[1], t); }

                ctx.save();
                rr(1, 1, W - 2, H - 2, 8);
                ctx.clip();
                const sg = ctx.createLinearGradient(0, 0, 0, hY);
                sg.addColorStop(0, rgb(top));
                sg.addColorStop(1, rgb(bot));
                ctx.fillStyle = sg;
                ctx.fillRect(0, 0, W, hY + 1);

                // Stars fade in as it gets dark
                const starA = Math.max(0, Math.min(1, (-alt - 4) / 10));
                if (starA > 0) {
                    let sd = 4242;
                    const rnd = () => { sd = (sd * 16807) % 2147483647; return (sd - 1) / 2147483646; };
                    for (let i = 0; i < 46; i++) {
                        const sx = rnd() * W, sy = rnd() * (hY - 8), r = 0.5 + rnd() * 1.1;
                        ctx.beginPath();
                        ctx.arc(sx, sy, r, 0, 2 * Math.PI);
                        ctx.fillStyle = `rgba(255,248,225,${starA * (0.35 + rnd() * 0.6)})`;
                        ctx.fill();
                    }
                }

                // Ammonites drifting in the sky: pale cloud-shells by day, starlit spirals by night
                function skyAmmonite(cx, cy, R0, rot, a) {
                    const b = Math.log(2) / (2 * Math.PI), tMax = 3 * 2 * Math.PI;
                    const r = th => R0 * Math.exp(b * (th - tMax));
                    const pt = (th, rr) => [cx + rr * Math.cos(th + rot), cy + rr * Math.sin(th + rot)];
                    const col = starA > 0.5 ? "255,246,220" : "255,252,244";
                    const fill = ctx.createRadialGradient(cx, cy, R0 * 0.1, cx, cy, R0 * 1.1);
                    fill.addColorStop(0, `rgba(${col},${0.10 * a})`);
                    fill.addColorStop(1, `rgba(${col},0)`);
                    ctx.fillStyle = fill;
                    ctx.beginPath();
                    ctx.arc(cx, cy, R0 * 1.1, 0, 2 * Math.PI);
                    ctx.fill();
                    ctx.strokeStyle = `rgba(${col},${0.32 * a})`;
                    ctx.lineWidth = 0.8;
                    for (let th = 2 * Math.PI + 0.3; th <= tMax; th += 0.3) {
                        const p1 = pt(th, r(th)), p2 = pt(th, r(th - 2 * Math.PI)), pm = pt(th - 0.12, (r(th) + r(th - 2 * Math.PI)) / 2);
                        ctx.beginPath();
                        ctx.moveTo(p1[0], p1[1]);
                        ctx.quadraticCurveTo(pm[0], pm[1], p2[0], p2[1]);
                        ctx.stroke();
                    }
                    ctx.strokeStyle = `rgba(${col},${0.55 * a})`;
                    ctx.lineWidth = 1.3;
                    ctx.beginPath();
                    for (let th = 0.7; th <= tMax; th += 0.07) {
                        const p = pt(th, r(th));
                        th === 0.7 ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]);
                    }
                    ctx.stroke();
                    // at night, stars sit along the shell like a constellation
                    if (starA > 0) {
                        for (let th = 2.5; th <= tMax; th += 1.6) {
                            const p = pt(th, r(th));
                            ctx.beginPath();
                            ctx.arc(p[0], p[1], 1.3, 0, 2 * Math.PI);
                            ctx.fillStyle = `rgba(255,250,230,${0.9 * starA})`;
                            ctx.fill();
                        }
                    }
                }
                const skyA = 0.55 + 0.45 * starA;
                skyAmmonite(W * 0.17, hY * 0.36, 17, 0.4, skyA);
                skyAmmonite(W * 0.83, hY * 0.30, 13, 2.6, skyA * 0.9);
                skyAmmonite(W * 0.58, hY * 0.22, 9, 4.4, skyA * 0.8);
                skyAmmonite(W * 0.36, hY * 0.62, 7, 1.2, skyA * 0.7);

                // Glow around the sun's position in the sky
                const sx = X(root.nowH), sy = Y(alt);
                if (alt > -10) {
                    const ga = Math.max(0, Math.min(1, (alt + 10) / 14));
                    const glow = ctx.createRadialGradient(sx, Math.min(sy, hY), 2, sx, Math.min(sy, hY), 120);
                    glow.addColorStop(0, `rgba(255,226,150,${0.55 * ga})`);
                    glow.addColorStop(1, "rgba(255,226,150,0)");
                    ctx.fillStyle = glow;
                    ctx.fillRect(0, 0, W, hY);
                }

                // Hour lines
                ctx.lineWidth = 1;
                for (let h = 3; h < 24; h += 3) {
                    ctx.strokeStyle = h % 6 === 0 ? "rgba(255,240,210,0.16)" : "rgba(255,240,210,0.07)";
                    ctx.beginPath();
                    ctx.moveTo(X(h) + 0.5, plotTop - 6);
                    ctx.lineTo(X(h) + 0.5, plotBot);
                    ctx.stroke();
                }

                // Earth: rolling hills along the horizon, dark loam below
                const eg = ctx.createLinearGradient(0, hY, 0, H);
                eg.addColorStop(0, "rgb(52,40,26)");
                eg.addColorStop(1, "rgb(22,16,10)");
                ctx.fillStyle = eg;
                ctx.beginPath();
                ctx.moveTo(0, H);
                for (let x = 0; x <= W; x += 4)
                    ctx.lineTo(x, hY - 3 - 4 * Math.sin(x * 0.021 + 1.3) - 2.5 * Math.sin(x * 0.057 + 0.4));
                ctx.lineTo(W, H);
                ctx.closePath();
                ctx.fill();
                // Fossil ammonites buried in the ground, carved in shallow relief
                function fossil(cx, cy, R0, rot) {
                    const b = Math.log(2) / (2 * Math.PI), tMax = 3.2 * 2 * Math.PI;
                    const r = th => R0 * Math.exp(b * (th - tMax));
                    const pt = (th, rr, o) => [cx + o + rr * Math.cos(th + rot), cy + o + rr * Math.sin(th + rot)];
                    const f = ctx.createRadialGradient(cx, cy, R0 * 0.1, cx, cy, R0);
                    f.addColorStop(0, "rgba(196,170,128,0.22)");
                    f.addColorStop(0.85, "rgba(170,140,100,0.16)");
                    f.addColorStop(1, "rgba(170,140,100,0)");
                    ctx.fillStyle = f;
                    ctx.beginPath();
                    ctx.arc(cx, cy, R0, 0, 2 * Math.PI);
                    ctx.fill();
                    for (const pass of [{ o: 0.8, col: "rgba(226,196,150,0.40)" }, { o: 0, col: "rgba(12,8,4,0.75)" }]) {
                        ctx.strokeStyle = pass.col;
                        ctx.lineWidth = 0.7;
                        for (let th = 2 * Math.PI + 0.4; th <= tMax; th += 0.28) {
                            const p1 = pt(th, r(th), pass.o), p2 = pt(th, r(th - 2 * Math.PI), pass.o), pm = pt(th - 0.12, (r(th) + r(th - 2 * Math.PI)) / 2, pass.o);
                            ctx.beginPath();
                            ctx.moveTo(p1[0], p1[1]);
                            ctx.quadraticCurveTo(pm[0], pm[1], p2[0], p2[1]);
                            ctx.stroke();
                        }
                        ctx.lineWidth = 1.1;
                        ctx.beginPath();
                        for (let th = 0.8; th <= tMax; th += 0.07) {
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
                // a few faint strata lines, then the fossils lying in them
                ctx.lineWidth = 1;
                for (const [k, a] of [[0.35, 0.10], [0.62, 0.08], [0.85, 0.07]]) {
                    const yy = hY + (H - hY) * k;
                    ctx.strokeStyle = `rgba(150,120,80,${a})`;
                    ctx.beginPath();
                    for (let x = 0; x <= W; x += 6)
                        x === 0 ? ctx.moveTo(x, yy + 1.5 * Math.sin(x * 0.03 + k * 9)) : ctx.lineTo(x, yy + 1.5 * Math.sin(x * 0.03 + k * 9));
                    ctx.stroke();
                }
                const gH = H - 20 - hY;   // ground above the hour labels
                // big ones, some partly buried past the bottom edge
                fossil(W * 0.09, hY + gH * 0.75, Math.min(20, gH * 0.62), 0.7);
                fossil(W * 0.30, hY + gH * 0.95, Math.min(13, gH * 0.42), 2.9);
                fossil(W * 0.50, hY + gH * 0.62, Math.min(16, gH * 0.5), 5.1);
                fossil(W * 0.71, hY + gH * 0.9, Math.min(21, gH * 0.66), 1.8);
                fossil(W * 0.92, hY + gH * 0.6, Math.min(14, gH * 0.45), 4.0);
                const relief = [{ "o": 0.8, "col": "rgba(226,196,150,0.40)", "w": 1 }, { "o": 0, "col": "rgba(12,8,4,0.75)", "w": 1 }];
                for (const [fx, fy, l, r] of [[0.2, 0.5, 44, 1.4], [0.4, 0.78, 34, -1.3], [0.6, 0.48, 40, -1.8], [0.82, 0.62, 36, 1.75]])
                    trilobite(W * fx, hY + gH * fy, Math.min(l, gH * 1.3), r, "rgba(180,150,110,0.16)", relief);

                ctx.strokeStyle = "rgba(240,200,140,0.35)";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(0, hY + 0.5);
                ctx.lineTo(W, hY + 0.5);
                ctx.stroke();

                // The sun's path: dashed below the horizon, gold above it
                ctx.setLineDash([3, 4]);
                ctx.strokeStyle = "rgba(230,200,150,0.35)";
                ctx.lineWidth = 1.4;
                ctx.beginPath();
                pts.forEach((p, i) => i === 0 ? ctx.moveTo(X(p.h), Y(p.alt)) : ctx.lineTo(X(p.h), Y(p.alt)));
                ctx.stroke();
                ctx.setLineDash([]);
                ctx.save();
                ctx.beginPath();
                ctx.rect(0, 0, W, hY);
                ctx.clip();
                // the part already travelled is brighter
                for (const pass of [0, 1]) {
                    ctx.strokeStyle = pass === 0 ? "rgba(255,214,120,0.95)" : "rgba(255,226,160,0.45)";
                    ctx.lineWidth = pass === 0 ? 3 : 2;
                    ctx.beginPath();
                    let started = false;
                    for (const p of pts) {
                        if (pass === 0 ? p.h > root.nowH : p.h < root.nowH)
                            continue;
                        started ? ctx.lineTo(X(p.h), Y(p.alt)) : ctx.moveTo(X(p.h), Y(p.alt));
                        started = true;
                    }
                    if (pass === 0 && started)
                        ctx.lineTo(sx, sy);
                    ctx.stroke();
                }
                ctx.restore();

                // Sunrise / noon / sunset marks
                function diamond(x, y, r, fill) {
                    ctx.beginPath();
                    ctx.moveTo(x, y - r); ctx.lineTo(x + r, y); ctx.lineTo(x, y + r); ctx.lineTo(x - r, y);
                    ctx.closePath();
                    ctx.fillStyle = fill;
                    ctx.fill();
                    ctx.strokeStyle = "rgba(30,16,4,0.8)";
                    ctx.lineWidth = 1;
                    ctx.stroke();
                }
                if (root.riseH >= 0) diamond(X(root.riseH), hY, 4.5, "rgb(236,170,96)");
                if (root.setH >= 0) diamond(X(root.setH), hY, 4.5, "rgb(214,120,84)");
                if (root.noonAlt > 0) {
                    ctx.strokeStyle = "rgba(255,226,160,0.35)";
                    ctx.setLineDash([2, 3]);
                    ctx.beginPath();
                    ctx.moveTo(X(root.noonH), Y(root.noonAlt) - 6);
                    ctx.lineTo(X(root.noonH), hY);
                    ctx.stroke();
                    ctx.setLineDash([]);
                    diamond(X(root.noonH), Y(root.noonAlt) - 9, 3.5, "rgb(255,226,140)");
                }

                // "Now" line
                ctx.strokeStyle = "rgba(255,244,220,0.4)";
                ctx.lineWidth = 1;
                ctx.beginPath();
                ctx.moveTo(sx + 0.5, plotTop - 6);
                ctx.lineTo(sx + 0.5, plotBot);
                ctx.stroke();

                // The sun itself (dim and cool when below the horizon)
                const up = alt > -0.833;
                if (up) {
                    ctx.strokeStyle = "rgba(255,220,130,0.8)";
                    ctx.lineWidth = 1.6;
                    for (let i = 0; i < 12; i++) {
                        const a = i * Math.PI / 6 + 0.13;
                        ctx.beginPath();
                        ctx.moveTo(sx + Math.cos(a) * 13, sy + Math.sin(a) * 13);
                        ctx.lineTo(sx + Math.cos(a) * (i % 2 ? 17 : 20), sy + Math.sin(a) * (i % 2 ? 17 : 20));
                        ctx.stroke();
                    }
                }
                const dg = ctx.createRadialGradient(sx - 3, sy - 3, 1, sx, sy, 10);
                dg.addColorStop(0, up ? "rgb(255,250,220)" : "rgba(220,200,170,0.75)");
                dg.addColorStop(0.55, up ? "rgb(255,204,92)" : "rgba(170,130,90,0.75)");
                dg.addColorStop(1, up ? "rgb(222,132,40)" : "rgba(110,80,52,0.75)");
                ctx.beginPath();
                ctx.arc(sx, sy, 10, 0, 2 * Math.PI);
                ctx.fillStyle = dg;
                ctx.fill();
                ctx.strokeStyle = up ? "rgba(120,60,10,0.9)" : "rgba(40,24,10,0.7)";
                ctx.lineWidth = 1.2;
                ctx.stroke();

                // Hour labels along the ground
                ctx.font = `13px "${fontRecia.name}"`;
                ctx.textAlign = "center";
                ctx.fillStyle = "rgba(236,214,178,0.85)";
                const mil = Config.settings.militaryTimeClockFormat;
                for (const h of [0, 6, 12, 18, 24]) {
                    const label = mil ? (h % 24 + ":00") : (h % 12 === 0 ? (h === 12 ? "noon" : "12a") : (h % 12) + (h < 12 ? "a" : "p"));
                    const x = Math.max(16, Math.min(W - 16, X(h)));
                    ctx.strokeStyle = "rgba(14,9,4,0.9)";
                    ctx.lineWidth = 3;
                    ctx.strokeText(label, x, H - 8);
                    ctx.fillText(label, x, H - 8);
                }
                ctx.restore();

                // Recessed window edge
                rr(1.5, 1.5, W - 3, H - 3, 8);
                ctx.strokeStyle = "rgba(0,0,0,0.65)";
                ctx.lineWidth = 3;
                ctx.stroke();
                rr(0.5, 0.5, W - 1, H - 1, 8.5);
                ctx.strokeStyle = "rgba(236,190,120,0.35)";
                ctx.lineWidth = 1;
                ctx.stroke();
            }
        }

        // Sunrise · Noon · Sunset
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 0
            Repeater {
                model: [
                    { "name": "Ortus", "sub": "sunrise", "h": root.riseH },
                    { "name": "Meridies", "sub": "noon", "h": root.noonAlt > 0 ? root.noonH : -1 },
                    { "name": "Occasus", "sub": "sunset", "h": root.setH }
                ]
                delegate: Column {
                    required property var modelData
                    width: sky.width / 3
                    spacing: 0
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.name
                        font.family: fontBoska.name
                        font.pixelSize: 19
                        font.weight: 600
                        color: Config.colors.accent
                        style: Text.Outline
                        styleColor: root.outline
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: root.fmtHour(modelData.h)
                        font.family: fontRecia.name
                        font.pixelSize: 20
                        font.weight: 700
                        color: Config.colors.textLight
                        style: Text.Outline
                        styleColor: root.outline
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: modelData.sub
                        font.family: fontDominica.name
                        font.pixelSize: 13
                        color: Config.colors.textLight
                        opacity: 0.75
                        style: Text.Outline
                        styleColor: root.outline
                    }
                }
            }
        }

        // Ornamental divider: ───◆───
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Rectangle { width: 110; height: 1; color: Qt.lighter(Config.colors.accentDark, 1.45); anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 7; height: 7; rotation: 45; color: Config.colors.accent; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 110; height: 1; color: Qt.lighter(Config.colors.accentDark, 1.45); anchors.verticalCenter: parent.verticalCenter }
        }

        Text {
            width: sky.width
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.WordWrap
            text: root.status()
            font.family: fontDominica.name
            font.pixelSize: 17
            color: Config.colors.textLight
            style: Text.Outline
            styleColor: root.outline
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.countdown() || " "
            font.family: fontBoska.name
            font.pixelSize: 18
            font.weight: 600
            color: Config.colors.accent
            style: Text.Outline
            styleColor: root.outline
        }
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.placeName + "  ·  " + root.fmtSpan(root.setH >= 0 && root.riseH >= 0 ? root.setH - root.riseH : 0) + " of daylight today"
            font.family: fontDominica.name
            font.pixelSize: 13
            color: Config.colors.textLight
            opacity: 0.7
            style: Text.Outline
            styleColor: root.outline
        }
    }
}
