import QtQuick
import QtQuick.Controls.Basic

// Shows which control the controller is adjusting, and how to finish.
Popup {
    id: frame
    required property var target
    required property string confirmLabel
    required property string cancelLabel
    parent: Overlay.overlay
    visible: !!target
    focus: false
    modal: false
    dim: false
    padding: 0
    margins: 0
    closePolicy: Popup.NoAutoClose
    enter: null
    exit: null
    readonly property point position: target && parent ? target.mapToItem(parent, 0, 0) : Qt.point(0, 0)
    x: position.x - 4
    y: position.y - 4
    width: target ? target.width + 8 : 0
    height: target ? target.height + 8 : 0
    background: Rectangle {
        color: "transparent"
        radius: Colors.controlRadius
        border.width: 2
        border.color: Colors.accent
    }
    contentItem: Item {
        enabled: false
        Rectangle {
            readonly property bool above: frame.y + frame.height + height + 8 > frame.parent.height
            y: above ? -height - 6 : frame.height + 6
            x: Math.max(0, Math.min(frame.width - width, (frame.width - width) / 2))
            width: hint.implicitWidth + 20
            height: hint.implicitHeight + 10
            radius: height / 2
            color: Colors.accent
            Text {
                id: hint
                anchors.centerIn: parent
                text: qsTr("Adjusting · %1 accept · %2 cancel").arg(frame.confirmLabel).arg(frame.cancelLabel)
                color: Colors.accentInk
                font.pixelSize: Typography.bodySmall
                font.weight: Font.DemiBold
            }
        }
    }
}
