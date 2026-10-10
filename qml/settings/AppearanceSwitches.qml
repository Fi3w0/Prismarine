import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Repeater {
    required property var controller
    required property string section

    model: section !== "Interface" && section !== "Library & covers" && section !== "Java & game" ? [] : [
        {
            name: "Animations",
            detail: "Hover lifts and smooth transitions.",
            key: "animations"
        },
        {
            name: "Screenshot covers",
            detail: "Use your newest screenshot when no custom cover is set.",
            key: "showScreenshots"
        },
        {
            name: "Deco frames",
            detail: "Thin brass frames around your covers.",
            key: "decoFrames"
        }
    ]
    delegate: ColumnLayout {
        required property var modelData
        Layout.fillWidth: true
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.border
        }
        RowLayout {
            Layout.fillWidth: true
            ColumnLayout {
                Layout.fillWidth: true
                Text {
                    text: modelData.name
                    color: Colors.text
                    font.pixelSize: 14
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.fillWidth: true
                    text: modelData.detail
                    color: Colors.subtext
                    font.pixelSize: 12
                    wrapMode: Text.Wrap
                }
            }
            ToggleSwitch {
                objectName: modelData.key + "Toggle"
                Accessible.name: modelData.name
                checked: controller.preferences[modelData.key]
                onToggled: controller.preferences[modelData.key] = checked
            }
        }
    }
}
