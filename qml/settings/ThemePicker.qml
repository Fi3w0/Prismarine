import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    required property var controller
    required property string section

    visible: section === "Interface"
    Layout.fillWidth: true
    spacing: 10
    Text {
        text: "Theme"
        color: Colors.text
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }
    Text {
        Layout.fillWidth: true
        text: "Dark is the default. System follows your desktop."
        wrapMode: Text.Wrap
        color: Colors.subtext
        font.pixelSize: 12
    }
    Rectangle {
        implicitWidth: options.implicitWidth + 8
        implicitHeight: 40
        radius: 10
        color: Colors.mantle
        border.color: Colors.border
        Row {
            id: options
            anchors.centerIn: parent
            spacing: 4
            Repeater {
                model: [{ label: "Deep sea", key: "deep" }, { label: "Light", key: "light" }, { label: "System", key: "system" }]
                delegate: AbstractButton {
                    id: option
                    required property var modelData
                    readonly property bool current: controller.preferences.theme === modelData.key
                    objectName: "theme_" + modelData.key
                    implicitWidth: label.implicitWidth + 28
                    implicitHeight: 32
                    hoverEnabled: true
                    Accessible.name: modelData.label + " theme"
                    onClicked: controller.preferences.theme = modelData.key
                    background: Rectangle {
                        radius: 8
                        color: option.current ? Colors.surfaceHi : option.hovered ? Qt.rgba(Colors.surfaceHi.r, Colors.surfaceHi.g, Colors.surfaceHi.b, 0.5) : "transparent"
                        border.color: option.current || option.visualFocus ? Colors.accent : "transparent"
                    }
                    contentItem: Text {
                        id: label
                        text: option.modelData.label
                        color: option.current ? Colors.text : Colors.subtext
                        font.pixelSize: 12
                        font.weight: option.current ? Font.DemiBold : Font.Normal
                        horizontalAlignment: Text.AlignHCenter
                        verticalAlignment: Text.AlignVCenter
                    }
                }
            }
        }
    }
}
