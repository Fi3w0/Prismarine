import QtQuick
import QtQuick.Controls

// Small inline action such as "View library →" or "← Library".
AbstractButton {
    id: link
    property color tint: Colors.accent
    property int pixelSize: 12
    property bool underline: true
    implicitWidth: label.implicitWidth
    implicitHeight: label.implicitHeight + 4
    hoverEnabled: true
    Accessible.name: text
    contentItem: Text {
        id: label
        text: link.text
        color: link.hovered ? Qt.lighter(link.tint, 1.2) : link.tint
        font.pixelSize: link.pixelSize
        font.underline: link.underline || link.hovered
        verticalAlignment: Text.AlignVCenter
    }
    background: Rectangle {
        color: "transparent"
        radius: 4
        border.color: link.visualFocus ? Colors.accent : "transparent"
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
