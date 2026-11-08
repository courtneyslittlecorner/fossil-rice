import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import ".."

// Brightness — the screen's light shown as a sun; companion to the Battery moon.
// The ring of 24 rays is the day's hours; each lit ray is ~4% of brightness.
// Drag the slider, scroll anywhere on the card, or click a ray to set brightness.
// Sets brightness through logind (no root needed); re-reads sysfs every few seconds
// so changes from the keyboard's brightness keys show up. Drag by empty space to move.
Rectangle {
    id: root

    property bool widgetBackground: true
    property var widgetData: null

    property string device: "intel_backlight"
    readonly property string sysPath: "/sys/class/backlight/" + device

    property int maxRaw: 0
    property real level: -1          // 0..1, what the widget shows
    property real wanted: -1         // 0..1, last value the user asked for
    property bool busy: false        // user interacting; don't let polling fight them
    readonly property real minLevel: 0.01  // never go fully black
    readonly property int percent: level < 0 ? -1 : Math.round(level * 100)
    readonly property real shown: Math.max(0, Math.min(1, level))

    width: 300
    height: content.implicitHeight + 48
    color: "transparent"

    function setLevel(v) {
        v = Math.max(minLevel, Math.min(1, v));
        level = v;
        wanted = v;
        busy = true;
        settle.restart();
        if (!writer.running)
            writeTimer.restart();
    }
    function nudge(delta) {
        setLevel((level < 0 ? 0.5 : level) + delta);
    }
    function moodName() {
        if (percent < 0)
            return "the sun is hidden";
        if (percent <= 10)
            return "embers before dawn";
        if (percent <= 30)
            return "first light";
        if (percent <= 55)
            return "the morning sun";
        if (percent <= 85)
            return "the afternoon sun";
        return "high noon";
    }

    Process {
        id: reader
        command: ["sh", "-c", `cat ${root.sysPath}/brightness ${root.sysPath}/max_brightness`]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length < 2 || root.busy)
                    return;
                const cur = parseInt(l[0]), max = parseInt(l[1]);
                if (!(max > 0))
                    return;
                root.maxRaw = max;
                root.level = cur / max;
            }
        }
    }
    Timer {
        interval: 3000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: if (!root.busy) reader.running = true
    }

    // Writes are coalesced: while one busctl call runs, only the latest value is kept.
    Process {
        id: writer
        property real sent: -1
        onExited: {
            if (Math.abs(root.wanted - sent) > 0.001)
                writeTimer.restart();
        }
    }
    Timer {
        id: writeTimer
        interval: 25
        onTriggered: {
            if (root.maxRaw <= 0 || root.wanted < 0)
                return;
            writer.sent = root.wanted;
            writer.command = ["busctl", "call", "org.freedesktop.login1", "/org/freedesktop/login1/session/auto",
                "org.freedesktop.login1.Session", "SetBrightness", "ssu", "backlight", root.device,
                String(Math.max(1, Math.round(root.wanted * root.maxRaw)))];
            writer.running = true;
        }
    }
    // After the user stops touching it, resume syncing with the hardware.
    Timer {
        id: settle
        interval: 1500
        onTriggered: root.busy = false
    }

    // Card backing: a carved slab of slate (see StoneBacking.qml)
    StoneBacking {
        anchors.fill: parent
        visible: root.widgetBackground
        seed: 6
    }

    // Move the card by dragging empty space; scroll anywhere to adjust.
    MouseArea {
        anchors.fill: parent
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.threshold: 4
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: (root.parent && root.parent.parent) ? root.parent.parent.width - root.width : 10000
        drag.maximumY: (root.parent && root.parent.parent) ? root.parent.parent.height - root.height : 10000
        onWheel: wheel => root.nudge(wheel.angleDelta.y > 0 ? 0.05 : (wheel.angleDelta.y < 0 ? -0.05 : 0))
        onReleased: {
            const d = root.widgetData;
            if (!d)
                return;
            Config.updateWidget(d.monitorName, d.widgetId, d.widgetName, Math.round(root.x), Math.round(root.y), d.enableBackground, d.widgetType);
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: 22
        spacing: 10

        // Heading
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "Vis Solis"
                font.family: fontBoska.name
                font.pixelSize: 28
                font.weight: 500
                color: Config.colors.accent
                DropShadow { anchors.fill: parent; source: parent; color: "Black"; opacity: 0.3; radius: 5 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "the light of the glass"
                font.family: fontDominica.name
                font.pixelSize: 15
                color: Config.colors.textLight
                opacity: 0.8
            }
        }

        // Sun dial
        Item {
            id: dial
            width: 200
            height: 200
            anchors.horizontalCenter: parent.horizontalCenter

            // Halo grows with brightness
            RectangularShadow {
                anchors.centerIn: parent
                width: 90 + 40 * root.shown
                height: width
                radius: width / 2
                blur: 60
                color: Config.colors.accent
                opacity: 0.12 + 0.45 * root.shown
                Behavior on opacity { NumberAnimation { duration: 250 } }
            }

            // 24 rays — the hours of the day. Long rays on the quarters. Click one to jump there.
            Repeater {
                model: 24
                Item {
                    id: ray
                    required property int index
                    readonly property bool lit: index < Math.round(root.shown * 24)
                    readonly property bool major: index % 6 === 5
                    width: 14
                    height: 200
                    x: (dial.width - width) / 2
                    y: 0
                    rotation: (index + 1) / 24 * 360
                    transformOrigin: Item.Center
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        y: ray.major ? 2 : 10
                        width: ray.major ? 4 : 3
                        height: ray.major ? 30 : 20
                        radius: width / 2
                        color: ray.lit ? Config.colors.accent : Config.colors.highlight
                        Behavior on color { ColorAnimation { duration: 200 } }
                    }
                    MouseArea {
                        width: parent.width
                        height: 36
                        cursorShape: Qt.PointingHandCursor
                        onClicked: root.setLevel((ray.index + 1) / 24)
                    }
                }
            }

            // Thin orbit line
            Rectangle {
                anchors.centerIn: parent
                width: 116
                height: 116
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Config.colors.accentDark
                opacity: 0.6
            }

            // The sun disc: dims toward the shadow color as brightness falls
            Rectangle {
                id: disc
                anchors.centerIn: parent
                width: 96
                height: 96
                radius: width / 2
                // blend highlight → accent by brightness (done by hand; Qt.tint misbehaves here)
                readonly property real t: 0.25 + 0.75 * root.shown
                readonly property color from: Config.colors.highlight
                readonly property color to: Config.colors.accent
                color: Qt.rgba(from.r + (to.r - from.r) * t, from.g + (to.g - from.g) * t, from.b + (to.b - from.b) * t, 1)
                border.width: 1.5
                border.color: Config.colors.accentDark
                Behavior on color { ColorAnimation { duration: 200 } }

                Text {
                    anchors.centerIn: parent
                    text: root.percent < 0 ? "…" : root.percent + "%"
                    font.family: fontRecia.name
                    font.pixelSize: 28
                    font.weight: 800
                    color: root.shown > 0.45 ? Config.colors.base : Config.colors.textLight
                }
            }
        }

        // Slider: a ruled track with a diamond seal
        Item {
            id: slider
            width: 220
            height: 28
            anchors.horizontalCenter: parent.horizontalCenter

            Rectangle {
                id: track
                anchors.verticalCenter: parent.verticalCenter
                x: 10
                width: parent.width - 20
                height: 4
                radius: 2
                color: Config.colors.highlight
                Rectangle {
                    width: parent.width * root.shown
                    height: parent.height
                    radius: 2
                    color: Config.colors.accent
                }
            }
            Rectangle {
                width: 14
                height: 14
                rotation: 45
                anchors.verticalCenter: parent.verticalCenter
                x: track.x + track.width * root.shown - width / 2
                color: Config.colors.accent
                border.width: 1
                border.color: Config.colors.base
                DropShadow { anchors.fill: parent; source: parent; color: "Black"; opacity: 0.35; radius: 4 }
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                cursorShape: Qt.PointingHandCursor
                function apply(mx) {
                    root.setLevel((mx - track.x) / track.width);
                }
                onPressed: mouse => apply(mouse.x)
                onPositionChanged: mouse => { if (pressed) apply(mouse.x); }
                onWheel: wheel => root.nudge(wheel.angleDelta.y > 0 ? 0.05 : (wheel.angleDelta.y < 0 ? -0.05 : 0))
            }
        }

        // Ornamental divider: ───◆───
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Rectangle { width: 80; height: 1; color: Config.colors.accentDark; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 7; height: 7; rotation: 45; color: Config.colors.accent; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 80; height: 1; color: Config.colors.accentDark; anchors.verticalCenter: parent.verticalCenter }
        }

        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.moodName()
            font.family: fontDominica.name
            font.pixelSize: 17
            color: Config.colors.textLight
        }
    }
}
