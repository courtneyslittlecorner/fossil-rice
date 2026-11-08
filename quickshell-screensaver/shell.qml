//@ pragma Env QS_NO_RELOAD_POPUP=1
// "Mare Antiquum" — the screensaver: an ancient sea over your fossil bed. Living ammonites jet
// about shell-first, trilobites crawl over the seafloor, marine snow drifts down through the light.
//
// Started by hypridle after a few idle minutes (see ~/.config/hypr/hypridle.conf), or by hand with
// screensaver.sh. Any key, click or real mouse movement closes it.
// Colors + sprites come from theme.json / sprites/, rebuilt per Quickshell theme by
// ~/.config/hypr/lock/make_lock.py.
import QtQuick
import Quickshell
import Quickshell.Io
import Quickshell.Wayland

ShellRoot {
    id: root

    FileView {
        id: themeFile
        path: Quickshell.shellDir + "/theme.json"
        blockLoading: true
    }
    readonly property var meta: {
        try { return JSON.parse(themeFile.text()); } catch (e) { return null; }
    }
    readonly property var col: meta ? meta.colors : ({
        waterTop: "#24464a", waterMid: "#122224", waterBottom: "#0a0c09", accent: "#a7b777",
        accentDark: "#747c5c", textLight: "#d0daed", ray: "#d0e2bf", snow: "#bcc9c2"
    })
    function sprite(p) { return "file://" + Quickshell.shellDir + "/" + p; }

    Variants {
        model: Quickshell.screens

        PanelWindow {
            id: win
            required property var modelData
            screen: modelData
            anchors { top: true; bottom: true; left: true; right: true }
            exclusionMode: ExclusionMode.Ignore
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.namespace: "fossil-screensaver"
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.Exclusive
            color: "black"

            Item {
                id: scene
                anchors.fill: parent
                focus: true
                opacity: 0
                Component.onCompleted: opacity = 1
                Behavior on opacity { NumberAnimation { duration: 2500; easing.type: Easing.InOutQuad } }

                property real t: 0
                // y of the seafloor crest at screen x (floor.top is sampled every `step` px of the image)
                function floorTop(x) {
                    if (!root.meta) return height - 180;
                    const f = root.meta.floor, k = width / (f.step * (f.top.length - 1));
                    const u = Math.max(0, Math.min(f.top.length - 1.001, x / (f.step * k)));
                    const i = Math.floor(u), a = f.top[i], b = f.top[i + 1];
                    return height - floorImg.height + (a + (b - a) * (u - i)) * floorImg.height / f.h;
                }

                Keys.onPressed: Qt.quit()

                // ── Water ──
                Rectangle {
                    anchors.fill: parent
                    gradient: Gradient {
                        GradientStop { position: 0.0; color: root.col.waterTop }
                        GradientStop { position: 0.55; color: root.col.waterMid }
                        GradientStop { position: 1.0; color: root.col.waterBottom }
                    }
                }

                // Shafts of light from the surface, slowly swaying
                Repeater {
                    model: 6
                    Rectangle {
                        required property int index
                        readonly property real seed: index * 1.7 + 0.4
                        width: 90 + (index * 53) % 170
                        height: scene.height * 1.5
                        x: scene.width * (0.08 + index * 0.16) + Math.sin(scene.t * 0.05 + seed) * 60
                        y: -scene.height * 0.15
                        rotation: 14 + Math.sin(scene.t * 0.03 + seed) * 4
                        transformOrigin: Item.Top
                        opacity: 0.05 + 0.05 * (0.5 + 0.5 * Math.sin(scene.t * 0.11 + seed * 2.3))
                        gradient: Gradient {
                            GradientStop { position: 0.0; color: root.col.ray }
                            GradientStop { position: 0.7; color: Qt.rgba(1, 1, 1, 0) }
                        }
                    }
                }

                // Far creatures sit behind the snow + floor, near ones in front (z set per creature)
                Repeater {
                    id: ammonites
                    model: 8
                    Image {
                        id: amm
                        required property int index
                        property real depth: 0.5
                        property int dir: -1          // -1: swims left (tentacles trail right, sprite as drawn)
                        property real baseY: 300
                        property real speed: 40
                        property real phase: Math.random() * 6.3
                        property real bobPh: Math.random() * 6.3
                        property int kind: index % 3
                        readonly property var info: root.meta ? root.meta.ammonites[kind] : null

                        source: info ? root.sprite(info.src) : ""
                        width: info ? info.w * (0.3 + 0.55 * depth) : 0
                        height: info ? info.h * (0.3 + 0.55 * depth) : 0
                        smooth: true
                        mipmap: true
                        z: depth > 0.62 ? 6 : 1
                        opacity: (0.32 + 0.68 * depth) * fade
                        property real fade: 1
                        transform: Scale { origin.x: amm.width / 2; xScale: amm.dir > 0 ? -1 : 1 }

                        function respawn(first) {
                            depth = Math.random();
                            dir = Math.random() < 0.5 ? -1 : 1;
                            speed = 18 + 40 * depth + Math.random() * 14;
                            baseY = scene.height * (0.06 + Math.random() * 0.6);
                            kind = Math.floor(Math.random() * 3);
                            x = first ? Math.random() * scene.width
                                      : (dir < 0 ? scene.width + 40 : -width - 40 - Math.random() * 400);
                        }
                        property bool ready: false
                        function step(dt) {
                            if (!ready) { if (scene.width < 10) return; respawn(true); ready = true; }
                            phase += dt * (0.9 + 0.3 * depth);
                            // jet propulsion: a quick surge every few seconds, then a glide
                            const s = Math.max(0, Math.sin(phase));
                            const surge = Math.pow(s, 6) * 2.4;
                            x += dir * speed * (0.35 + surge) * dt;
                            y = baseY + Math.sin(scene.t * 0.35 + bobPh) * 22 * (0.5 + depth) - surge * 4;
                            rotation = dir * (Math.sin(scene.t * 0.5 + bobPh) * 5 - surge * 6);
                            if ((dir < 0 && x < -width - 60) || (dir > 0 && x > scene.width + 60))
                                respawn(false);
                        }
                    }
                }

                // Marine snow
                Repeater {
                    id: snow
                    model: 90
                    Rectangle {
                        required property int index
                        property real sp: 6 + Math.random() * 16
                        property real swayPh: Math.random() * 6.3
                        property real x0: -1
                        width: 1.5 + Math.random() * 2.5
                        height: width
                        radius: width / 2
                        color: root.col.snow
                        opacity: 0.12 + Math.random() * 0.35
                        z: Math.random() < 0.35 ? 7 : 3
                        function step(dt) {
                            if (x0 < 0) { if (scene.width < 10) return; x0 = Math.random() * scene.width; y = Math.random() * scene.height; }
                            y += sp * dt;
                            x = x0 + Math.sin(scene.t * 0.3 + swayPh) * 14;
                            if (y > scene.height) { y = -6; x0 = Math.random() * scene.width; }
                        }
                    }
                }

                // Seafloor: a slice of the fossil-bed rock
                Image {
                    id: floorImg
                    z: 4
                    source: root.sprite("sprites/seafloor.png")
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: root.meta ? root.meta.floor.h * width / (root.meta.floor.step * (root.meta.floor.top.length - 1)) : 300
                    smooth: true
                }

                // Trilobites crawling over the floor
                Repeater {
                    id: trilobites
                    model: 4
                    Image {
                        id: tri
                        required property int index
                        property int dir: index % 2 ? 1 : -1
                        property real sc: 0.55 + Math.random() * 0.25
                        property real lane: 30 + Math.random() * 80   // how far down the floor's face
                        property real pause: 0
                        property real walkPh: 0
                        property bool frameB: false
                        readonly property var info: root.meta ? root.meta.trilobite : null
                        z: 5
                        source: root.sprite(frameB ? "sprites/trilobite1.png" : "sprites/trilobite0.png")
                        width: info ? info.w * sc : 0
                        height: info ? info.h * sc : 0
                        smooth: true
                        mipmap: true
                        x: -1000

                        function step(dt) {
                            if (x === -1000) { if (scene.width < 10) return; x = Math.random() * scene.width; }
                            if (pause > 0) { pause -= dt; return; }
                            const cxp = x + width / 2;
                            x += dir * 16 * sc * 2 * dt;
                            walkPh += dt;
                            if (walkPh > 0.16) { walkPh = 0; frameB = !frameB; }
                            const ahead = scene.floorTop(cxp + dir * 20), here = scene.floorTop(cxp);
                            y = here + lane - height / 2;
                            rotation = 90 + Math.atan2(ahead - here, 20 * dir) * 57.3;   // sprite faces up; turn it to the heading
                            if (Math.random() < dt / 9) pause = 1 + Math.random() * 4;     // stop to graze now and then
                            if (Math.random() < dt / 40) dir = -dir;                         // and sometimes turn back
                            if (x < -width) { x = scene.width; }
                            if (x > scene.width) { x = -width; }
                        }
                    }
                }

                // Time + date, drifting a little each minute so nothing burns in
                Column {
                    id: clock
                    z: 2        // behind the near ammonites, in front of the far ones
                    spacing: 4
                    property real ox: 0
                    property real oy: 0
                    x: (scene.width - width) / 2 + ox
                    y: scene.height * 0.12 + oy
                    opacity: 0.8
                    Behavior on ox { NumberAnimation { duration: 8000; easing.type: Easing.InOutSine } }
                    Behavior on oy { NumberAnimation { duration: 8000; easing.type: Easing.InOutSine } }

                    Text {
                        id: timeText
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: "Boska Variable"
                        font.weight: Font.Medium
                        font.pixelSize: 132
                        color: root.col.accent
                        style: Text.Outline
                        styleColor: Qt.rgba(0, 0, 0, 0.25)
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: "───  ◆  ───"
                        font.family: "Recia Variable"
                        font.pixelSize: 15
                        color: root.col.accentDark
                    }
                    Text {
                        id: dateText
                        anchors.horizontalCenter: parent.horizontalCenter
                        font.family: "Recia Variable"
                        font.italic: true
                        font.pixelSize: 21
                        color: root.col.textLight
                        opacity: 0.85
                    }
                    Text {
                        anchors.horizontalCenter: parent.horizontalCenter
                        topPadding: 6
                        text: "Mare Antiquum"
                        font.family: "Boska Variable"
                        font.pixelSize: 17
                        font.letterSpacing: 3
                        color: root.col.accent
                        opacity: 0.6
                    }
                }
                Timer {
                    interval: 1000; running: true; repeat: true; triggeredOnStart: true
                    property int lastMin: -1
                    onTriggered: {
                        const d = new Date();
                        timeText.text = Qt.formatTime(d, "HH:mm");
                        dateText.text = Qt.formatDate(d, "dddd · d MMMM yyyy");
                        if (d.getMinutes() !== lastMin) {
                            if (lastMin >= 0) { clock.ox = (Math.random() - 0.5) * 240; clock.oy = (Math.random() - 0.5) * 90; }
                            lastMin = d.getMinutes();
                        }
                    }
                }

                FrameAnimation {
                    running: true
                    onTriggered: {
                        const dt = Math.min(0.1, frameTime);
                        scene.t += dt;
                        for (let i = 0; i < ammonites.count; i++) ammonites.itemAt(i).step(dt);
                        for (let i = 0; i < snow.count; i++) snow.itemAt(i).step(dt);
                        for (let i = 0; i < trilobites.count; i++) trilobites.itemAt(i).step(dt);
                    }
                }

                // Close on click or a deliberate mouse movement (ignore the first moments + tiny jitter)
                MouseArea {
                    anchors.fill: parent
                    z: 100
                    hoverEnabled: true
                    cursorShape: Qt.BlankCursor
                    property point start: Qt.point(-1, -1)
                    property double born: Date.now()
                    onPressed: Qt.quit()
                    onWheel: Qt.quit()
                    onPositionChanged: mouse => {
                        if (Date.now() - born < 1500 || start.x < 0) { start = Qt.point(mouse.x, mouse.y); return; }
                        if (Math.abs(mouse.x - start.x) + Math.abs(mouse.y - start.y) > 24) Qt.quit();
                    }
                }
            }
        }
    }
}
