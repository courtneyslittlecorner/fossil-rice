import QtQuick
import ".."

// Small button used in the Quest Board settings pane
Rectangle {
    id: pbtn
    property string label: ""
    property string fontFamily: ""
    property bool enabledBtn: true
    signal clicked()
    width: pbLabel.implicitWidth + 28
    height: 32
    radius: 6
    opacity: enabledBtn ? 1 : 0.5
    color: pbArea.containsMouse && enabledBtn ? Config.colors.accent : Config.colors.shadow
    border.width: 1
    border.color: Config.colors.accent
    Text {
        id: pbLabel
        anchors.centerIn: parent
        text: pbtn.label
        font.family: pbtn.fontFamily
        font.pixelSize: 14
        color: pbArea.containsMouse && pbtn.enabledBtn ? Config.colors.base : Config.colors.accent
    }
    MouseArea {
        id: pbArea
        anchors.fill: parent
        hoverEnabled: true
        cursorShape: pbtn.enabledBtn ? Qt.PointingHandCursor : Qt.ArrowCursor
        onClicked: if (pbtn.enabledBtn) pbtn.clicked()
    }
}
