import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

AbstractButton {
    id: shortcut
    property string glyph: "library"
    Layout.fillWidth: true
    Layout.preferredWidth: 1
    implicitHeight: 62
    hoverEnabled: true
    Accessible.name: text
    ToolTip.visible: hovered
    ToolTip.text: text
    ToolTip.delay: 500
    background: Rectangle {
        radius: 10
        color: shortcut.hovered || shortcut.down ? Colors.surfaceHi : Colors.inset
        border.color: shortcut.visualFocus ? Colors.accent : "transparent"
    }
    contentItem: Column {
        spacing: 6
        topPadding: 10
        LineIcon {
            anchors.horizontalCenter: parent.horizontalCenter
            name: shortcut.glyph
            implicitWidth: 18
            implicitHeight: 18
            tint: shortcut.hovered || shortcut.visualFocus ? Colors.accent : Colors.text
        }
        Text {
            width: parent.width
            text: shortcut.text
            color: Colors.text
            font.pixelSize: Typography.caption
            horizontalAlignment: Text.AlignHCenter
            elide: Text.ElideRight
        }
    }
}
