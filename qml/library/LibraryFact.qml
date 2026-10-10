import QtQuick
import QtQuick.Layouts

ColumnLayout {
    property string label: ""
    property string value: ""
    spacing: 5
    Text { Layout.fillWidth: true; text: parent.label; color: Colors.subtext; font.pixelSize: 11; elide: Text.ElideRight }
    Text { Layout.fillWidth: true; text: parent.value; color: Colors.text; font.pixelSize: 16; font.weight: Font.Medium; elide: Text.ElideRight }
}
