import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Flat sidebar entry: a highlighted row rather than a framed button.
Button {
    id: item
    property string detail: ""
    property color detailColor: Colors.subtext
    Layout.fillWidth: true
    implicitHeight: 34
    hoverEnabled: true
    leftPadding: 12
    rightPadding: 12
    font.pixelSize: 13
    font.weight: checked ? Font.DemiBold : Font.Normal
    Accessible.name: text
    contentItem: RowLayout {
        spacing: 8
        Text {
            Layout.fillWidth: true
            text: item.text
            font: item.font
            color: item.checked ? Colors.text : item.hovered ? Colors.text : Colors.subtext
            elide: Text.ElideRight
            verticalAlignment: Text.AlignVCenter
        }
        Text {
            visible: item.detail !== ""
            text: item.detail
            color: item.detailColor
            font.pixelSize: 11
        }
    }
    background: Rectangle {
        radius: 8
        color: item.checked ? Colors.surfaceHi : item.hovered ? Qt.rgba(Colors.surfaceHi.r, Colors.surfaceHi.g, Colors.surfaceHi.b, 0.5) : "transparent"
        border.color: item.visualFocus ? Colors.accent : "transparent"
        Behavior on color { ColorAnimation { duration: Colors.animations ? 140 : 0 } }
    }
    HoverHandler { cursorShape: Qt.PointingHandCursor }
}
