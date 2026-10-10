import QtQuick
import QtQuick.Controls

Switch {
    id: control
    implicitWidth: control.text ? label.implicitWidth + 60 : 54
    implicitHeight: 32
    padding: 4
    contentItem: Text {
        id: label
        text: control.text
        font.pixelSize: 13
        color: Colors.text
        leftPadding: control.text ? 56 : 0
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        opacity: control.enabled ? 1 : 0.45
    }
    indicator: Rectangle {
        x: control.leftPadding
        y: (control.height - height) / 2
        width: 42
        height: 24
        radius: 12
        color: control.checked ? Colors.accent : Colors.surfaceHi
        border.color: control.visualFocus ? Colors.bone : control.checked ? Colors.accent : Colors.border
        opacity: control.enabled ? 1 : 0.45
        Rectangle {
            x: control.checked ? parent.width - width - 3 : 3
            y: 3
            width: 18
            height: 18
            radius: 9
            color: control.checked ? Colors.accentInk : Colors.subtext
            Behavior on x {
                NumberAnimation {
                    duration: Colors.animations ? 220 : 0
                }
            }
        }
    }
}
