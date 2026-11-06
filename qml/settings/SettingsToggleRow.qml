import QtQuick
import QtQuick.Layouts

RowLayout {
    id: row
    required property string title
    property string detail: ""
    required property bool value
    signal toggled(bool value)
    Layout.fillWidth: true
    spacing: 20
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        Text { Layout.fillWidth: true; text: row.title; color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
        Text { Layout.fillWidth: true; text: row.detail; color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
    }
    ToggleSwitch { objectName: row.objectName + "Toggle"; Accessible.name: row.title; checked: row.value; onToggled: row.toggled(checked) }
}
