import QtQuick
import QtQuick.Controls

MouseArea {
    anchors.fill: parent
    hoverEnabled: true
    cursorShape: Qt.IBeamCursor
    signal picked()
    signal renameRequested()
    onClicked: picked()
    onDoubleClicked: renameRequested()
    ToolTip.visible: containsMouse
    ToolTip.delay: 650
    ToolTip.text: "Double-click to rename · F2"
}
