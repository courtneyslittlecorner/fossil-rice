import Quickshell
import Quickshell.Io
import QtQuick
import Qt.labs.folderlistmodel
import Qt5Compat.GraphicalEffects
import ".."

// Photo Frame — a slow slideshow of the photos you choose, in the antiquity style.
// Put photos (or symlinks to them) in ~/Pictures/Frame; the frame notices new and removed files by itself.
// Click the right half of the photo for the next one, the left half for the previous.
// It moves on by itself every few minutes (see `interval`).
// Drag the frame by its moulding or the mat; its position is saved to widgets.json.
// Click the brass nameplate to open the album folder.
Rectangle {
    id: root

    property bool widgetBackground: true
    // Set by WidgetScreen so a drag can save the new position to widgets.json
    property var widgetData: null

    readonly property string photoDir: Quickshell.env("HOME") + "/Pictures/Frame"
    readonly property int interval: 3 * 60 * 1000   // time between photos
    // Frame geometry: moulding width, mat margins (the bottom margin is wider and holds the nameplate)
    readonly property real frameW: 30
    readonly property real matSide: 18
    readonly property real matTop: 18
    readonly property real matBottom: 56
    readonly property real photoWidth: width - 2 * frameW - 2 * matSide

    property int index: 0
    readonly property int count: photos.count
    readonly property bool empty: count === 0

    // Brass for the nameplate and photo fillet, warmed slightly toward the theme accent
    readonly property color brass: Qt.tint("#c49c54", Qt.rgba(Config.colors.accent.r, Config.colors.accent.g, Config.colors.accent.b, 0.3))
    readonly property color brassLight: Qt.lighter(brass, 1.25)
    readonly property color brassDark: Qt.darker(brass, 1.7)

    width: 380
    height: 2 * frameW + matTop + photoBox.height + matBottom
    color: "transparent"

    function savePosition() {
        const d = root.widgetData;
        if (d)
            Config.updateWidget(d.monitorName, d.widgetId, d.widgetName, Math.round(root.x), Math.round(root.y), d.enableBackground, d.widgetType);
    }
    function show(i) {
        if (root.empty)
            return;
        root.index = (i + root.count) % root.count;
        slideTimer.restart();
    }
    // "summer_at_the_lake-2.jpg" -> "Summer at the lake 2"
    function prettyName(name) {
        let s = name.replace(/\.[^.]+$/, "").replace(/[_\-]+/g, " ").trim();
        return s.length ? s.charAt(0).toUpperCase() + s.slice(1) : name;
    }

    FolderListModel {
        id: photos
        folder: "file://" + root.photoDir
        nameFilters: ["*.jpg", "*.jpeg", "*.png", "*.webp", "*.gif", "*.bmp", "*.JPG", "*.JPEG", "*.PNG", "*.WEBP"]
        showDirs: false
        showHidden: false
        sortField: FolderListModel.Name
        caseSensitive: false
        onCountChanged: if (root.index >= count) root.index = 0
    }
    readonly property string currentUrl: root.empty ? "" : photos.get(Math.min(root.index, root.count - 1), "fileUrl") + ""
    readonly property string currentName: root.empty ? "" : root.prettyName(photos.get(Math.min(root.index, root.count - 1), "fileName"))

    Timer {
        id: slideTimer
        interval: root.interval
        repeat: true
        running: root.count > 1
        onTriggered: root.index = (root.index + 1) % root.count
    }

    Process { id: mkdirProc; command: ["mkdir", "-p", root.photoDir] }
    Process { id: openFolder; command: [Config.settings.execCommands.files || "nemo", root.photoDir] }
    Component.onCompleted: mkdirProc.running = true

    // ── The frame: a walnut moulding with brass corners, gold inlay, ammonites and flowers ──
    WoodBacking {
        anchors.fill: parent
        visible: root.widgetBackground
        singleBoard: true
        seed: 31
        frameWidth: root.frameW
        moulding: true
        paintInner: false
        flowerSize: 1.0
    }

    // Drag anywhere on the frame or mat to move it.
    MouseArea {
        anchors.fill: parent
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.threshold: 4
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: (root.parent && root.parent.parent) ? root.parent.parent.width - root.width : 10000
        drag.maximumY: (root.parent && root.parent.parent) ? root.parent.parent.height - root.height : 10000
        onReleased: root.savePosition()
    }

    // ── The mat: ivory card with a bevel-cut window ──────────────────────
    Rectangle {
        id: mat
        x: root.frameW
        y: root.frameW
        width: root.width - 2 * root.frameW
        height: root.height - 2 * root.frameW
        gradient: Gradient {
            GradientStop { position: 0; color: "#ebe3d0" }
            GradientStop { position: 1; color: "#dcd2bc" }
        }

        // Shadow cast by the frame onto the mat (deeper at the top and left, light comes from the top-left)
        Rectangle {
            width: parent.width; height: 9
            gradient: Gradient { GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.42) } GradientStop { position: 1; color: "transparent" } }
        }
        Rectangle {
            width: 7; height: parent.height
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: Qt.rgba(0, 0, 0, 0.32) } GradientStop { position: 1; color: "transparent" } }
        }
        Rectangle {
            anchors.right: parent.right
            width: 4; height: parent.height
            gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.16) } }
        }
        Rectangle {
            anchors.bottom: parent.bottom
            width: parent.width; height: 4
            gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: Qt.rgba(0, 0, 0, 0.18) } }
        }
    }

    // The bevelled window cut into the mat: the white core shows on the four 45° faces.
    // The bottom and right faces tilt up toward the light; the top and left face away from it.
    Canvas {
        id: bevel
        readonly property real b: 5
        x: photoBox.x - b
        y: photoBox.y - b
        width: photoBox.width + 2 * b
        height: photoBox.height + 2 * b
        antialiasing: true
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"), W = width, H = height, b = bevel.b;
            ctx.reset();
            const face = (pts, col) => {
                ctx.beginPath();
                pts.forEach((p, i) => i === 0 ? ctx.moveTo(p[0], p[1]) : ctx.lineTo(p[0], p[1]));
                ctx.closePath();
                ctx.fillStyle = col;
                ctx.fill();
            };
            face([[0, 0], [W, 0], [W - b, b], [b, b]], "#cbc2ad");              // top
            face([[0, 0], [b, b], [b, H - b], [0, H]], "#d6cdb9");              // left
            face([[W, 0], [W, H], [W - b, H - b], [W - b, b]], "#f4efe4");      // right
            face([[0, H], [b, H - b], [W - b, H - b], [W, H]], "#fbf8f1");      // bottom
            ctx.strokeStyle = "rgba(90,70,40,0.35)";
            ctx.lineWidth = 1;
            ctx.strokeRect(0.5, 0.5, W - 1, H - 1);
        }
    }

    // The photo itself, sized to the photo's shape (within reason) and cross-faded on change.
    Item {
        id: photoBox
        x: root.frameW + root.matSide
        y: root.frameW + root.matTop
        width: root.photoWidth
        readonly property real aspect: front.status === Image.Ready && front.implicitWidth > 0
            ? front.implicitHeight / front.implicitWidth : 0.75
        height: root.empty ? 200 : Math.max(180, Math.min(400, width * aspect))
        Behavior on height { NumberAnimation { duration: 450; easing.type: Easing.InOutCubic } }
        clip: true

        Rectangle { anchors.fill: parent; color: "#1c1812" }

        // Two layers: `front` shows the current photo, `back` holds the previous one while it fades out.
        Image {
            id: back
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            autoTransform: true
            asynchronous: true
            sourceSize.width: 720
            smooth: true
        }
        Image {
            id: front
            anchors.fill: parent
            fillMode: Image.PreserveAspectCrop
            autoTransform: true   // honour phone/camera rotation
            asynchronous: true
            sourceSize.width: 720
            smooth: true
            source: root.currentUrl
            opacity: 0
            onSourceChanged: opacity = 0
            onStatusChanged: if (status === Image.Ready) fadeIn.restart()
            NumberAnimation {
                id: fadeIn
                target: front; property: "opacity"; from: 0; to: 1
                duration: 700; easing.type: Easing.InOutQuad
                onFinished: back.source = front.source
            }
        }
        // the photo's edge, just under the bevel
        Rectangle {
            anchors.fill: parent
            color: "transparent"
            border.width: 1
            border.color: Qt.rgba(0, 0, 0, 0.35)
        }

        // Empty frame
        Column {
            visible: root.empty
            anchors.centerIn: parent
            spacing: 6
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "The frame awaits"
                font.family: fontBoska.name
                font.pixelSize: 24
                font.weight: 500
                color: "#e8dcc0"
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: "place photos in ~/Pictures/Frame"
                font.family: fontDominica.name
                font.pixelSize: 14
                color: "#bfb197"
            }
        }

        // Click: left half = previous, right half = next. Arrows appear on hover.
        MouseArea {
            id: photoArea
            anchors.fill: parent
            hoverEnabled: true
            enabled: root.count > 1
            cursorShape: Qt.PointingHandCursor
            onClicked: mouse => root.show(root.index + (mouse.x < width / 2 ? -1 : 1))
        }
        Repeater {
            model: [{ glyph: "‹", left: true }, { glyph: "›", left: false }]
            delegate: Rectangle {
                required property var modelData
                visible: photoArea.containsMouse
                readonly property bool lit: photoArea.containsMouse && ((photoArea.mouseX < photoBox.width / 2) === modelData.left)
                anchors.verticalCenter: parent.verticalCenter
                x: modelData.left ? 10 : photoBox.width - width - 10
                width: 30; height: 30; radius: 15
                color: Qt.rgba(0, 0, 0, lit ? 0.6 : 0.35)
                border.width: 1
                border.color: lit ? root.brassLight : root.brass
                Text {
                    anchors.centerIn: parent
                    anchors.verticalCenterOffset: -2
                    text: parent.modelData.glyph
                    font.family: fontBoska.name
                    font.pixelSize: 24
                    color: root.brassLight
                }
            }
        }
    }

    // ── Glass: a faint diagonal reflection across the mat and photo ──────
    Canvas {
        x: mat.x
        y: mat.y
        width: mat.width
        height: mat.height
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"), W = width, H = height;
            ctx.reset();
            const g = ctx.createLinearGradient(0, 0, W, H * 0.9);
            g.addColorStop(0, "rgba(255,255,255,0.07)");
            g.addColorStop(0.22, "rgba(255,255,255,0.02)");
            g.addColorStop(0.34, "rgba(255,255,255,0)");
            g.addColorStop(0.4, "rgba(255,255,255,0.09)");
            g.addColorStop(0.47, "rgba(255,255,255,0.03)");
            g.addColorStop(0.52, "rgba(255,255,255,0)");
            g.addColorStop(1, "rgba(255,255,255,0)");
            ctx.fillStyle = g;
            ctx.fillRect(0, 0, W, H);
        }
    }

    // ── Nameplate: a brass plaque on the mat. Click it to open the album. ─
    Item {
        id: plaque
        visible: root.widgetBackground || !root.empty
        anchors.horizontalCenter: parent.horizontalCenter
        y: photoBox.y + photoBox.height + (root.matBottom - height) / 2
        width: Math.min(root.photoWidth - 20, Math.max(caption.implicitWidth + 44, 150))
        height: caption.implicitHeight + 12

        // soft shadow on the mat
        Rectangle {
            x: 1.5; y: 2
            width: parent.width; height: parent.height
            radius: 3
            color: Qt.rgba(0.15, 0.1, 0.04, 0.35)
        }
        Rectangle {
            anchors.fill: parent
            radius: 3
            gradient: Gradient {
                GradientStop { position: 0; color: root.brassLight }
                GradientStop { position: 0.5; color: root.brass }
                GradientStop { position: 1; color: Qt.darker(root.brass, 1.25) }
            }
            border.width: 1
            border.color: Qt.rgba(0.08, 0.05, 0.02, 0.9)
            // bevelled inner edge
            Rectangle {
                anchors.fill: parent
                anchors.margins: 3
                radius: 2
                color: "transparent"
                border.width: 1
                border.color: Qt.rgba(0.2, 0.12, 0.04, 0.45)
            }
            // screws
            Repeater {
                model: [0, 1]
                delegate: Rectangle {
                    required property int modelData
                    width: 6; height: 6; radius: 3
                    anchors.verticalCenter: parent.verticalCenter
                    x: modelData === 0 ? 8 : parent.width - 14
                    gradient: Gradient {
                        GradientStop { position: 0; color: Qt.lighter(root.brassLight, 1.2) }
                        GradientStop { position: 1; color: root.brassDark }
                    }
                    border.width: 1
                    border.color: Qt.rgba(0.08, 0.05, 0.02, 0.8)
                    Rectangle { anchors.centerIn: parent; width: 4; height: 1; rotation: 35 + 50 * parent.modelData; color: Qt.rgba(0.1, 0.06, 0.02, 0.7) }
                }
            }
        }

        Column {
            id: caption
            anchors.centerIn: parent
            spacing: 0
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(implicitWidth, root.photoWidth - 64)
                horizontalAlignment: Text.AlignHCenter
                elide: Text.ElideRight
                text: root.empty ? "The album" : root.currentName
                font.family: fontBoska.name
                font.pixelSize: 17
                font.weight: 600
                color: "#2a1a08"
                style: Text.Raised          // light edge below the letters: reads as engraved
                styleColor: Qt.rgba(1, 0.95, 0.8, 0.45)
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: plaqueArea.containsMouse ? "open the album" : (root.index + 1) + " of " + root.count
                font.family: fontDominica.name
                font.pixelSize: 11
                color: "#3a260e"
                style: Text.Raised
                styleColor: Qt.rgba(1, 0.95, 0.8, 0.35)
            }
        }
        MouseArea {
            id: plaqueArea
            anchors.fill: parent
            hoverEnabled: true
            cursorShape: Qt.PointingHandCursor
            onClicked: openFolder.running = true
        }
    }
}
