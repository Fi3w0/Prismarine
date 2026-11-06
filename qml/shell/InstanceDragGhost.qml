import QtQuick

// Follows the pointer while an instance is dragged onto a sidebar group.
Rectangle {
    id: ghost
    required property var controller
    objectName: "instanceDragGhost"
    z: 1000
    visible: !!ghost.controller.draggingId
    width: Math.min(280, ghostLabel.implicitWidth + 44)
    height: 34
    radius: 9
    color: Colors.surfaceHi
    border.color: Colors.accent
    Drag.active: !!ghost.controller.draggingId
    Drag.keys: ["prismarine/instance"]
    Drag.hotSpot.x: 14
    Drag.hotSpot.y: height / 2
    Row {
        anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
        spacing: 8
        LineIcon { name: "folder"; tint: Colors.accent; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
        Text {
            id: ghostLabel
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, 220)
            text: ghost.controller.draggingName
            color: Colors.text
            font.pixelSize: Typography.body
            elide: Text.ElideRight
        }
    }
}
