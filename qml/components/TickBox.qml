import QtQuick
import QtQuick.Controls

// Compact square checkbox for table selection; `partial` shows a dash.
AbstractButton {
    id: box
    property bool partial: false
    checkable: true
    implicitWidth: 18
    implicitHeight: 18
    hoverEnabled: true
    background: Rectangle {
        radius: 5
        color: box.checked || box.partial ? Colors.accent : box.hovered ? Colors.surfaceHi : "transparent"
        border.color: box.visualFocus ? Colors.bone : box.checked || box.partial ? Colors.accent : Colors.subtext
        Behavior on color { ColorAnimation { duration: Colors.animations ? 120 : 0 } }
    }
    contentItem: Text {
        text: box.checked ? "✓" : box.partial ? "–" : ""
        color: Colors.accentInk
        font.pixelSize: 12
        font.weight: Font.Bold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
