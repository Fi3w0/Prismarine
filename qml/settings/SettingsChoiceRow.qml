import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

GridLayout {
    id: row
    required property string title
    property string detail: ""
    required property var choices
    required property var value
    signal chosen(var value)
    Layout.fillWidth: true
    columns: width < 620 ? 1 : 2
    columnSpacing: 20
    rowSpacing: 12
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 5
        Text { Layout.fillWidth: true; text: row.title; color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold; wrapMode: Text.Wrap }
        Text { Layout.fillWidth: true; visible: !!text; text: row.detail; color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
    }
    RowLayout {
        spacing: 8
        Layout.alignment: row.columns === 1 ? Qt.AlignLeft : Qt.AlignRight
        Repeater {
            model: row.choices
            delegate: AbstractButton {
                id: choice
                required property var modelData
                readonly property bool selected: row.value === modelData.value
                objectName: row.objectName + "_" + modelData.value
                implicitWidth: Math.max(74, label.implicitWidth + 24)
                implicitHeight: 42
                hoverEnabled: true
                Accessible.name: row.title + ": " + modelData.label
                Accessible.checkable: true
                Accessible.checked: selected
                onClicked: row.chosen(modelData.value)
                background: Rectangle {
                    radius: 10
                    color: choice.selected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.13) : choice.hovered ? Colors.surfaceHi : Colors.surface
                    border.color: choice.selected || choice.visualFocus ? Colors.accent : Colors.border
                }
                contentItem: Text { id: label; text: choice.modelData.label; color: Colors.text; font.pixelSize: Typography.bodySmall; font.weight: Font.DemiBold; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter }
            }
        }
    }
}
