import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ColumnLayout {
    required property var controller
    required property string section

    visible: section !== "About"
    Layout.fillWidth: true
    spacing: 10
    Text {
        text: "Accent colour"
        color: Colors.text
        font.pixelSize: Typography.control
        font.weight: Font.DemiBold
    }
    Text {
        Layout.fillWidth: true
        wrapMode: Text.Wrap
        text: "Presets keep buttons and accent text readable in both themes."
        color: Colors.subtext
        font.pixelSize: Typography.bodySmall
    }
    Row {
        spacing: 14
        Repeater {
            model: ["#46d1bb", "#7aa2ff", "#f0a35e", "#b892f2", "#d8c39a"]
            delegate: Button {
                required property color modelData
                required property int index
                objectName: "accentPreset_" + index
                ToolTip.visible: hovered
                ToolTip.text: [qsTr("Seafoam"), qsTr("Blue"), qsTr("Amber"), qsTr("Lavender"), qsTr("Sand")][index]
                width: 32
                height: 32
                Accessible.name: ToolTip.text
                onClicked: controller.preferences.accentColor = modelData
                contentItem: Text {
                    text: controller.preferences.accentColor === modelData ? "✓" : ""
                    color: "#06211d"
                    font.pixelSize: Typography.body
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
                background: Rectangle {
                    radius: 16
                    color: modelData
                    border.width: 2
                    border.color: controller.preferences.accentColor === modelData ? Colors.bone : "transparent"
                }
            }
        }
    }
}
