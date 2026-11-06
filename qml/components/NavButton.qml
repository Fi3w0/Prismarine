import QtQuick
import QtQuick.Controls

Button {
    id: control
    property string iconName: "library"
    property string hint: ""
    // Optional short text under the icon.
    property string label: ""
    readonly property bool labelShown: label !== ""
    implicitWidth: labelShown ? 64 : 44
    implicitHeight: labelShown ? 58 : 44
    hoverEnabled: true
    property real iconRotation: 0
    scale: down ? 0.92 : 1
    Behavior on scale { NumberAnimation { duration: Colors.animations ? Colors.motionFeedbackDuration : 0; easing.type: Easing.OutCubic } }
    onClicked: if (iconName === "refresh" && Colors.animations) spin.restart()
    NumberAnimation { id: spin; target: control; property: "iconRotation"; from: 0; to: 360; duration: 600; easing.type: Easing.InOutCubic }
    Accessible.name: hint
    background: Rectangle {
        radius: control.labelShown ? 14 : 12
            Behavior on color { ColorAnimation { duration: Colors.animations ? Colors.motionFeedbackDuration : 0 } }
        color: control.checked ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.14)
            : control.hovered ? Colors.surfaceHi : "transparent"
        border.color: control.activeFocus ? Colors.accent : "transparent"
    }
    contentItem: Item {
        Column {
            anchors.centerIn: parent
            spacing: 3
            LineIcon {
                anchors.horizontalCenter: parent.horizontalCenter
                rotation: control.iconRotation
                name: control.iconName
                Behavior on tint { ColorAnimation { duration: Colors.animations ? Colors.motionFeedbackDuration : 0 } }
                tint: control.checked ? Colors.accent : Colors.subtext
            }
            Text {
                anchors.horizontalCenter: parent.horizontalCenter
                visible: control.labelShown
                text: control.label
                font.pixelSize: Typography.bodySmall
                font.weight: Font.Medium
                color: control.checked ? Colors.text : Colors.subtext
            }
        }
    }
    ToolTip.visible: hovered && hint !== "" && !(labelShown && hint === label)
    ToolTip.text: hint
    ToolTip.delay: 400
}
