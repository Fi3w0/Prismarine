import QtQuick
import QtQuick.Controls
import QtQuick.Shapes

Button {
    id: control
    property bool primary: false
    property bool danger: false
    readonly property bool angular: primary && text.indexOf("PLAY") >= 0
    property bool compact: false
    implicitWidth: compact ? 42 : Math.max(160, contentItem.implicitWidth + 32)
    implicitHeight: angular ? 54 : 40
    hoverEnabled: true
    scale: down ? 0.97 : 1
    Behavior on scale { NumberAnimation { duration: Colors.animations ? 160 : 0; easing.type: Easing.OutCubic } }
    padding: 12
    font.pixelSize: angular ? 18 : 14
    font.weight: primary ? Font.ExtraBold : Font.Normal
    font.letterSpacing: angular ? 2 : 0
    Accessible.name: text
    contentItem: Text {
        text: control.text
        font: control.font
        color: control.primary ? Colors.accentInk : control.danger ? Colors.danger : Colors.text
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
        opacity: control.enabled ? 1 : 0.4
    }
    background: Item {
        opacity: control.enabled || !control.primary ? 1 : 0.4
        Rectangle {
            anchors.fill: parent
            visible: !control.angular
            radius: 10
            Behavior on color { ColorAnimation { duration: Colors.animations ? 180 : 0 } }
            color: control.primary ? (control.down ? Colors.accentDark : control.hovered ? Qt.lighter(Colors.accent, 1.1) : Colors.accent) : control.hovered || control.checked ? Colors.surfaceHi : Colors.surface
            border.color: control.activeFocus ? Colors.accent : control.primary ? Colors.accent : control.danger ? Qt.rgba(Colors.danger.r, Colors.danger.g, Colors.danger.b, 0.45) : Colors.border
        }
        Shape {
            anchors.fill: parent
            visible: control.angular
            ShapePath {
                strokeWidth: control.activeFocus ? 2 : 0
                strokeColor: Colors.bone
                fillColor: control.down ? Colors.accentDark : control.hovered ? Qt.lighter(Colors.accent, 1.1) : Colors.accent
                Behavior on fillColor { ColorAnimation { duration: Colors.animations ? 180 : 0 } }
                startX: 12
                startY: 0
                PathLine {
                    x: control.width - 12
                    y: 0
                }
                PathLine {
                    x: control.width
                    y: control.height / 2
                }
                PathLine {
                    x: control.width - 12
                    y: control.height
                }
                PathLine {
                    x: 12
                    y: control.height
                }
                PathLine {
                    x: 0
                    y: control.height / 2
                }
                PathLine {
                    x: 12
                    y: 0
                }
            }
        }
    }
}
