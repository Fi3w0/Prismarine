import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

RowLayout {
    required property var controller

    Layout.fillWidth: true
    Layout.leftMargin: 28
    Layout.rightMargin: 28
    spacing: 4
    Repeater {
        model: [
            {
                title: "Overview",
                key: "overview"
            },
            {
                title: "Mods",
                key: "mods"
            },
            {
                title: "Resource packs",
                key: "resourcepacks"
            },
            {
                title: "Shaders",
                key: "shaders"
            },
            {
                title: "Worlds",
                key: "worlds"
            },
            {
                title: "Servers",
                key: "servers"
            },
            {
                title: "Screenshots",
                key: "screenshots"
            },
            {
                title: "Logs",
                key: "logs"
            }
        ]
        delegate: Button {
            id: tab
            required property var modelData
            readonly property int count: modelData.key === "mods" ? (controller.details.info.mods || 0) : 0
            implicitHeight: 46
            leftPadding: 14
            rightPadding: 14
            hoverEnabled: true
            checked: controller.instanceTab === modelData.key
            onClicked: controller.openTab(modelData.key)
            Accessible.name: modelData.title
            contentItem: Row {
                spacing: 7
                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    text: tab.modelData.title
                    color: tab.checked ? Colors.bone : tab.hovered ? Colors.text : Colors.subtext
                    font.family: Colors.displayFont
                    font.pixelSize: 14
                    font.letterSpacing: 1.5
                }
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    visible: tab.count > 0
                    width: countLabel.implicitWidth + 12
                    height: 18
                    radius: 9
                    color: Colors.surfaceHi
                    Text {
                        id: countLabel
                        anchors.centerIn: parent
                        text: tab.count
                        color: Colors.subtext
                        font.pixelSize: 10
                    }
                }
            }
            background: Item {
                Rectangle {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    width: tab.checked ? parent.width : 0
                    height: 2
                    color: Colors.accent
                    Behavior on width { NumberAnimation { duration: Colors.animations ? 200 : 0; easing.type: Easing.OutCubic } }
                }
                Rectangle {
                    anchors.fill: parent
                    color: "transparent"
                    border.color: tab.visualFocus ? Colors.accent : "transparent"
                    radius: 4
                }
            }
        }
    }
    Item {
        Layout.fillWidth: true
    }
    TextLink {
        text: "Edit in Prism dialog ↗"
        tint: Colors.subtext
        underline: false
        visible: !!controller.details.instanceId && parent.width > 1080
        onClicked: controller.instances.editInPrism(controller.details.instanceId)
    }
}
