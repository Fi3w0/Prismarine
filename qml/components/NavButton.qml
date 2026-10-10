import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string iconName: "library"
    property string hint: ""
    implicitWidth: 44
    implicitHeight: 44
    hoverEnabled: true
    property real iconRotation: 0
    scale: down ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: Colors.animations ? 170 : 0; easing.type: Easing.OutCubic } }
    onClicked: if (iconName === "refresh" && Colors.animations) spin.restart()
    NumberAnimation { id: spin; target: control; property: "iconRotation"; from: 0; to: 360; duration: 600; easing.type: Easing.InOutCubic }
    Accessible.name: hint
    background: Rectangle {
        radius: 12
        Behavior on color { ColorAnimation { duration: Colors.animations ? 180 : 0 } }
        color: control.checked || control.hovered ? Colors.surfaceHi : "transparent"
        border.color: control.activeFocus ? Colors.accent : "transparent"
    }
    contentItem: Item {
        LineIcon {
            anchors.centerIn: parent
            rotation: control.iconRotation
            name: control.iconName
            Behavior on tint { ColorAnimation { duration: Colors.animations ? 180 : 0 } }
            tint: control.checked ? Colors.accent : Colors.subtext
        }
    }
    ToolTip.visible: hovered
    ToolTip.text: hint
    ToolTip.delay: 400
}
