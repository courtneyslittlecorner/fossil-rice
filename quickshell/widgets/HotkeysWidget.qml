import Quickshell
import QtQuick
import Qt5Compat.GraphicalEffects
import ".."

// Hotkeys — a grimoire of the Hyprland keybinds from ~/.config/hypr/hyprland.lua, written on a page of a spellbook.
// The list below is written by hand: if you change a bind there, update `sections` here too.
// Drag the card by any empty space; its position is saved to widgets.json.
// The card starts folded down to just its heading; click it anywhere to unfold, click the title to fold it again.
Rectangle {
    id: root

    property bool widgetBackground: true
    // Set by WidgetScreen so a drag can save the new position to widgets.json
    property var widgetData: null
    property bool collapsed: true

    width: 400
    // page margins: top = cover + 18, bottom = cover + stacked page edges + 18
    readonly property real vMargins: book.cover + 18 + book.cover + book.edges + 18
    height: content.implicitHeight + vMargins
    // Room left below the card before the screen edge, so a tall list scrolls instead of running off-screen.
    readonly property real room: (parent && parent.parent) ? Math.max(260, parent.parent.height - y - 50) : 900
    color: "transparent"
    Behavior on height { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

    // Each key is one keycap; a "1–0" style range is shown as a single cap.
    readonly property var sections: [
        { title: "Apps & Windows", binds: [
            { keys: ["Super", "Enter"],          does: "Terminal" },
            { keys: ["Super", "D"],              does: "App launcher" },
            { keys: ["Super", "E"],              does: "File manager" },
            { keys: ["Super", "Q"],              does: "Close window" },
            { keys: ["Super", "F"],              does: "Fullscreen" },
            { keys: ["Super", "Shift", "Space"], does: "Float / tile" },
            { keys: ["Super", "Shift", "S"],     does: "Screenshot region" },
            { keys: ["Super", "L"],              does: "Lock screen" },
            { keys: ["Close lid"],               does: "Lock screen" },
            { keys: ["Super", "Shift", "E"],     does: "Exit Hyprland" }
        ]},
        { title: "Focus & Arrange", binds: [
            { keys: ["Super", "←↑↓→"],           does: "Focus window" },
            { keys: ["Super", "Shift", "←↑↓→"],  does: "Move window" }
        ]},
        { title: "Workspaces", binds: [
            { keys: ["Super", "1–0"],            does: "Go to workspace" },
            { keys: ["Super", "Shift", "1–0"],   does: "Send window there" }
        ]},
        { title: "Mouse", binds: [
            { keys: ["Super", "LMB drag"],       does: "Move window" },
            { keys: ["Super", "RMB drag"],       does: "Resize window" }
        ]},
        { title: "Media Keys", binds: [
            { keys: ["Vol ±"],                   does: "Volume 5%" },
            { keys: ["Mute"],                    does: "Mute speakers" },
            { keys: ["Mic"],                     does: "Mute microphone" },
            { keys: ["Bright ±"],                does: "Brightness 10%" }
        ]}
    ]

    // Ink colors for writing on the page
    readonly property color ink: root.widgetBackground ? "#2e1f10" : Config.colors.textLight
    readonly property color inkFaded: root.widgetBackground ? "#76644a" : Config.colors.accentDark
    readonly property color rubric: root.widgetBackground ? "#8e2a1e" : Config.colors.accent   // red ink for headings

    // Card backing: a page of a leather-bound spellbook (see SpellbookBacking.qml)
    SpellbookBacking {
        id: book
        anchors.fill: parent
        visible: root.widgetBackground
        seed: 9
    }

    // Drag anywhere on empty space to move; position is saved on release.
    MouseArea {
        id: dragArea
        anchors.fill: parent
        cursorShape: drag.active ? Qt.ClosedHandCursor : Qt.OpenHandCursor
        drag.target: root
        drag.threshold: 4
        drag.minimumX: 0
        drag.minimumY: 0
        drag.maximumX: (root.parent && root.parent.parent) ? root.parent.parent.width - root.width : 10000
        drag.maximumY: (root.parent && root.parent.parent) ? root.parent.parent.height - root.height : 10000
        // A plain click (not a drag) on the folded card unfolds it
        property point pressedAt
        onPressed: pressedAt = Qt.point(root.x, root.y)
        onClicked: if (root.collapsed && root.x === pressedAt.x && root.y === pressedAt.y) root.collapsed = false
        onReleased: {
            const d = root.widgetData;
            if (!d)
                return;
            Config.updateWidget(d.monitorName, d.widgetId, d.widgetName, Math.round(root.x), Math.round(root.y), d.enableBackground, d.widgetType);
        }
    }

    // Ornamental divider: ───◆───
    Component {
        id: divider
        Row {
            spacing: 8
            Rectangle { width: 110; height: 1; color: root.inkFaded; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 7; height: 7; rotation: 45; color: root.rubric; anchors.verticalCenter: parent.verticalCenter }
            Rectangle { width: 110; height: 1; color: root.inkFaded; anchors.verticalCenter: parent.verticalCenter }
        }
    }

    Column {
        id: content
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: book.pageY + 18
        anchors.leftMargin: book.pageX + 30                                    // clear of the gutter
        anchors.rightMargin: book.width - book.pageX - book.pageW + 18
        spacing: 10

        // Heading
        Column {
            id: heading
            anchors.horizontalCenter: parent.horizontalCenter
            spacing: 4
            // Illuminated title: a big red capital outlined in gold, then the rest in ink
            Item {
                anchors.horizontalCenter: parent.horizontalCenter
                width: titleRow.implicitWidth
                height: titleRow.implicitHeight
            Row {
                id: titleRow
                spacing: 1
                Text {
                    id: dropCap
                    text: "I"
                    font.family: fontBoska.name
                    font.pixelSize: 40
                    font.weight: 700
                    color: root.rubric
                    style: Text.Outline
                    styleColor: "#c8a04e"
                }
                Text {
                    anchors.baseline: dropCap.baseline
                    text: "ncantations"
                    font.family: fontBoska.name
                    font.pixelSize: 28
                    font.weight: 600
                    color: titleArea.containsMouse ? root.rubric : root.ink
                    Behavior on color { ColorAnimation { duration: 120 } }
                }
            }
                MouseArea {
                    id: titleArea
                    anchors.fill: parent
                    hoverEnabled: true
                    cursorShape: Qt.PointingHandCursor
                    onClicked: root.collapsed = !root.collapsed
                }
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                text: root.collapsed ? "the keys of power · click to unfold" : "the keys of power"
                font.family: fontDominica.name
                font.pixelSize: 15
                color: root.inkFaded
            }
            Loader {
                anchors.horizontalCenter: parent.horizontalCenter
                sourceComponent: divider
            }
        }

        // Sections — scroll with the mouse wheel when they don't fit on screen
        Flickable {
            id: list
            visible: !root.collapsed
            width: content.width
            height: root.collapsed ? 0 : Math.min(sectionCol.implicitHeight, root.room - root.vMargins - heading.implicitHeight - 40)
            contentHeight: sectionCol.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds
            flickableDirection: Flickable.VerticalFlick
            interactive: contentHeight > height

        Column {
        id: sectionCol
        width: list.width
        spacing: 6
        Repeater {
            model: root.sections
            delegate: Column {
                id: section
                required property var modelData
                width: content.width
                spacing: 1

                Text {
                    text: section.modelData.title.toUpperCase()
                    font.family: fontDominica.name
                    font.pixelSize: 13
                    font.letterSpacing: 2
                    color: root.rubric
                    bottomPadding: 1
                }

                Repeater {
                    model: section.modelData.binds
                    delegate: Item {
                        id: bindRow
                        required property var modelData
                        width: section.width
                        height: 20

                        Row {
                            id: caps
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 4
                            Repeater {
                                model: bindRow.modelData.keys
                                delegate: Row {
                                    required property string modelData
                                    required property int index
                                    spacing: 4
                                    Text {
                                        visible: index > 0
                                        anchors.verticalCenter: parent.verticalCenter
                                        text: "+"
                                        font.family: fontRecia.name
                                        font.pixelSize: 12
                                        color: root.inkFaded
                                    }
                                    Rectangle {
                                        anchors.verticalCenter: parent.verticalCenter
                                        width: capText.implicitWidth + 14
                                        height: 18
                                        radius: 3
                                        color: root.widgetBackground ? Qt.rgba(0.45, 0.3, 0.12, 0.12) : Config.colors.shadow
                                        border.width: 1
                                        border.color: root.widgetBackground ? Qt.rgba(0.18, 0.12, 0.06, 0.75) : Config.colors.highlight
                                        // keycap lip
                                        Rectangle {
                                            anchors.left: parent.left
                                            anchors.right: parent.right
                                            anchors.bottom: parent.bottom
                                            anchors.margins: 1
                                            height: 2
                                            radius: 2
                                            color: root.inkFaded
                                            opacity: 0.35
                                        }
                                        Text {
                                            id: capText
                                            anchors.centerIn: parent
                                            anchors.verticalCenterOffset: -1
                                            text: modelData
                                            font.family: fontRecia.name
                                            font.pixelSize: 12
                                            font.weight: 600
                                            color: root.ink
                                        }
                                    }
                                }
                            }
                        }

                        Text {
                            anchors.verticalCenter: parent.verticalCenter
                            anchors.right: parent.right
                            anchors.left: caps.right
                            anchors.leftMargin: 10
                            horizontalAlignment: Text.AlignRight
                            elide: Text.ElideRight
                            text: bindRow.modelData.does
                            font.family: fontRecia.name
                            font.pixelSize: 14
                            color: root.ink
                        }
                    }
                }
            }
        }

        }
        }

        // Closing flourish; reads "scroll for more" while the list is cut off
        Text {
            visible: !root.collapsed && list.interactive && !list.atYEnd
            anchors.horizontalCenter: parent.horizontalCenter
            text: "scroll for more ▾"
            font.family: fontDominica.name
            font.pixelSize: 13
            color: root.inkFaded
        }
        Loader {
            visible: !root.collapsed
            anchors.horizontalCenter: parent.horizontalCenter
            sourceComponent: divider
        }
    }
}
