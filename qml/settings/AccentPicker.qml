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
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }
    Text {
        text: "Buttons, selection, and highlights."
        color: Colors.subtext
        font.pixelSize: 12
    }
    Row {
        spacing: 14
        Repeater {
            model: ["#46d1bb", "#7aa2ff", "#f0a35e", "#b892f2", "#d8c39a"]
            delegate: Button {
                required property color modelData
                width: 32
                height: 32
                Accessible.name: "Accent colour " + modelData
                onClicked: controller.preferences.accentColor = modelData
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
