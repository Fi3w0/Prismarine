import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MenuItem {
    id: item
    property bool danger: false
    property string hint: ""
    implicitHeight: 36
    leftPadding: 12
    rightPadding: 12
    contentItem: RowLayout {
        spacing: 10
        Text {
            Layout.fillWidth: true
            text: item.text
            color: item.danger ? Colors.danger : item.enabled ? Colors.text : Colors.subtext
            font.pixelSize: 13
            elide: Text.ElideRight
            opacity: item.enabled ? 1 : 0.55
        }
        Text {
            visible: !!item.hint || item.checked || !!item.subMenu
            text: item.checked ? "✓" : item.subMenu ? "›" : item.hint
            color: item.checked ? Colors.accent : Colors.subtext
            font.pixelSize: 12
        }
    }
    background: Rectangle {
        radius: 8
        color: item.highlighted ? Colors.surfaceHi : "transparent"
    }
}
