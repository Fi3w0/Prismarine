import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ItemDelegate {
    id: action
    property string glyph: "library"
    property string trailing: "›"
    Layout.fillWidth: true
    implicitHeight: 44
    padding: 10
    background: Rectangle { radius: 8; color: action.hovered || action.activeFocus ? Colors.surfaceHi : "transparent"; Behavior on color { ColorAnimation { duration: Colors.animations ? 180 : 0 } } }
    contentItem: RowLayout {
        spacing: 10
        LineIcon { name: action.glyph; implicitWidth: 18; implicitHeight: 18; tint: action.hovered ? Colors.accent : Colors.subtext }
        Text { Layout.fillWidth: true; text: action.text; color: Colors.text; font.pixelSize: 13; elide: Text.ElideRight }
        Text { text: action.trailing; color: Colors.subtext; font.pixelSize: 15 }
    }
}
