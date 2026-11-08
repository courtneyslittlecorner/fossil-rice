import Quickshell
import Quickshell.Io
import QtQuick
import QtQuick.Effects
import Qt5Compat.GraphicalEffects
import ".."

// Battery — the charge shown as a phase of the moon.
// The moon waxes (lit from the right) while charging and wanes (lit from the left) on battery.
// The ring of 28 beads around it is a lunar month; each lit bead is ~3.5% of charge.
// Reads /sys/class/power_supply/BAT0 every few seconds. Drag by empty space to move; position is saved.
Rectangle {
    id: root

    property bool widgetBackground: true
    // Set by WidgetScreen so a drag can save the new position to widgets.json
    property var widgetData: null

    property string batteryPath: "/sys/class/power_supply/BAT0"

    // Battery state
    property int percent: -1
    property string status: "Unknown" // Charging | Discharging | Full | Not charging
    property real energyNow: 0
    property real energyFull: 0
    property real powerNow: 0

    readonly property bool charging: status === "Charging"
    readonly property bool resting: status === "Full" || status === "Not charging"
    readonly property bool low: percent >= 0 && percent <= 15 && !charging
    readonly property real fraction: Math.max(0, Math.min(1, percent / 100))
    readonly property color lightColor: low ? Config.colors.danger : Config.colors.accent

    width: 300
    height: content.implicitHeight + 48
    color: "transparent"

    function hoursText(h) {
        if (!isFinite(h) || h <= 0 || h > 48)
            return "";
        const mins = Math.round(h * 60);
        const hh = Math.floor(mins / 60);
        const mm = mins % 60;
        return hh > 0 ? `${hh}h ${mm}m` : `${mm}m`;
    }
    function phaseName() {
        if (percent < 0)
            return "the moon is hidden";
        if (resting)
            return percent >= 95 ? "full moon · at rest" : "the moon holds still";
        if (charging)
            return percent >= 95 ? "nearly full" : (percent >= 50 ? "waxing gibbous" : "waxing crescent");
        if (low)
            return "the light grows faint";
        return percent >= 50 ? "waning gibbous" : "waning crescent";
    }
    function timeText() {
        if (powerNow <= 0 || resting)
            return "";
        if (charging)
            return root.hoursText((energyFull - energyNow) / powerNow) + " until full";
        return root.hoursText(energyNow / powerNow) + " remain";
    }

    Process {
        id: reader
        command: ["sh", "-c", `cd ${root.batteryPath} && cat status capacity energy_now energy_full power_now 2>/dev/null`]
        stdout: StdioCollector {
            onStreamFinished: {
                const l = text.trim().split("\n");
                if (l.length < 2)
                    return;
                root.status = l[0];
                root.percent = parseInt(l[1]);
                root.energyNow = parseFloat(l[2]) || 0;
                root.energyFull = parseFloat(l[3]) || 0;
                root.powerNow = parseFloat(l[4]) || 0;
            }
        }
    }
    Timer {
        interval: 5000
        running: true
        repeat: true
        triggeredOnStart: true
        onTriggered: reader.running = true
    }

    // Card backing: a carved slab of slate (see StoneBacking.qml)
    StoneBacking {
        anchors.fill: parent
        visible: root.widgetBackground
        seed: 4
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
                text: "Vis Lunae"
                font.family: fontBoska.name
                font.pixelSize: 28
                font.weight: 500
                color: Config.colors.accent
                DropShadow { anchors.fill: parent; source: parent; color: "Black"; opacity: 0.3; radius: 5 }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "the stored light"
                font.family: fontDominica.name
                font.pixelSize: 15
                color: Config.colors.textLight
                opacity: 0.8
            }
        }

        // Moon dial — drawn at 200px and scaled down so this card matches the Brightness card's size
        Item {
            width: 200
            height: Math.round(200 * dial.scale)
            anchors.horizontalCenter: parent.horizontalCenter
        Item {
            id: dial
            width: 200
            height: 200
            anchors.centerIn: parent
            scale: 0.805

            // Soft halo; breathes while charging
            RectangularShadow {
                anchors.centerIn: parent
                width: 120
                height: 120
                radius: width / 2
                blur: 60
                color: root.lightColor
                property real pulse: 0
                opacity: root.charging ? 0.2 + 0.4 * pulse : 0.18 + 0.25 * root.fraction
                SequentialAnimation on pulse {
                    running: root.charging
                    loops: Animation.Infinite
                    NumberAnimation { from: 0; to: 1; duration: 1600; easing.type: Easing.InOutSine }
                    NumberAnimation { from: 1; to: 0; duration: 1600; easing.type: Easing.InOutSine }
                }
            }

            // Ring of 28 beads — one lunar month
            Repeater {
                model: 28
                Rectangle {
                    required property int index
                    readonly property real a: (index / 28) * 2 * Math.PI - Math.PI / 2
                    readonly property bool lit: index < Math.round(root.fraction * 28)
                    width: index % 7 === 0 ? 8 : 5
                    height: width
                    rotation: 45
                    x: dial.width / 2 + 92 * Math.cos(a) - width / 2
                    y: dial.height / 2 + 92 * Math.sin(a) - height / 2
                    color: lit ? root.lightColor : Config.colors.highlight
                    Behavior on color { ColorAnimation { duration: 300 } }
                }
            }
            // Thin orbit line
            Rectangle {
                anchors.centerIn: parent
                width: 160
                height: 160
                radius: width / 2
                color: "transparent"
                border.width: 1
                border.color: Config.colors.accentDark
                opacity: 0.6
            }

            // The moon itself
            Canvas {
                id: moon
                anchors.centerIn: parent
                width: 132
                height: 132
                antialiasing: true

                property real f: root.fraction
                property bool waxing: root.charging || root.resting
                property color lit: root.lightColor
                property color dark: Config.colors.highlight
                property color stroke: Config.colors.accentDark
                onFChanged: requestPaint()
                onWaxingChanged: requestPaint()
                onLitChanged: requestPaint()
                onDarkChanged: requestPaint()
                onStrokeChanged: requestPaint()
                Behavior on f { NumberAnimation { duration: 600; easing.type: Easing.OutCubic } }

                onPaint: {
                    const ctx = getContext("2d");
                    const cx = width / 2, cy = height / 2, r = width / 2 - 2;
                    ctx.reset();

                    // Dark side
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.fillStyle = dark;
                    ctx.fill();

                    // Lit side: outer limb, then back along the terminator ellipse
                    if (f > 0.001) {
                        const s = waxing ? 1 : -1;
                        const steps = 64;
                        ctx.beginPath();
                        for (let i = 0; i <= steps; i++) {
                            const t = -Math.PI / 2 + Math.PI * i / steps;
                            const x = cx + s * r * Math.cos(t), y = cy + r * Math.sin(t);
                            i === 0 ? ctx.moveTo(x, y) : ctx.lineTo(x, y);
                        }
                        for (let i = steps; i >= 0; i--) {
                            const t = -Math.PI / 2 + Math.PI * i / steps;
                            ctx.lineTo(cx + s * r * (1 - 2 * f) * Math.cos(t), cy + r * Math.sin(t));
                        }
                        ctx.closePath();
                        ctx.fillStyle = lit;
                        ctx.fill();
                    }

                    // Outline
                    ctx.beginPath();
                    ctx.arc(cx, cy, r, 0, 2 * Math.PI);
                    ctx.lineWidth = 1.5;
                    ctx.strokeStyle = stroke;
                    ctx.stroke();
                }
            }
        }
        }

        // Percentage
        Text {
            anchors.horizontalCenter: parent.horizontalCenter
            text: root.percent < 0 ? "…" : root.percent + "%"
            font.family: fontRecia.name
            font.pixelSize: 34
            font.weight: 800
            color: root.lightColor
            Behavior on color { ColorAnimation { duration: 300 } }
            DropShadow { anchors.fill: parent; source: parent; color: "Black"; opacity: 0.3; radius: 5 }
        }

        // Ornamental divider: ───◆───
        Row {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 8
            Rectangle { width: 80; height: 1; color: Config.colors.accentDark; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 7; height: 7; rotation: 45; color: Config.colors.accent; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 80; height: 1; color: Config.colors.accentDark; anchors.verticalCenter: parent.verticalCenter }
        }

        // Phase + time remaining
        Column {
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 2
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.phaseName()
                font.family: fontDominica.name
                font.pixelSize: 17
                color: root.low ? Config.colors.danger : Config.colors.textLight
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.timeText() || " "  // a space keeps the line's height when empty, so the card size never changes
                font.family: fontDominica.name
                font.pixelSize: 14
                color: Config.colors.textLight
                opacity: 0.7
            }
        }
    }
}
