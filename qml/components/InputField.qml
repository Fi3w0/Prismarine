import QtQuick
import QtQuick.Controls

TextField {
    id: control
    implicitHeight: 40
    leftPadding: 14
    rightPadding: 14
    font.pixelSize: 14
    color: Colors.text
    placeholderTextColor: Colors.subtext
    background: Rectangle {
        color: Colors.surfaceHi
        radius: 10
        border.color: control.activeFocus ? Colors.accent : Colors.border
    }
}
