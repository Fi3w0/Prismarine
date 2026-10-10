import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    required property var controller

    Layout.fillWidth: true
    Layout.preferredHeight: 300
    color: Colors.surface
    radius: 16
    border.color: Colors.border
    ColumnLayout {
        anchors {
            fill: parent
            margins: 20
        }
        spacing: 12
        Text {
            text: "Jump into a world"
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: 20
            font.letterSpacing: 2
        }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            model: controller.instances.worlds
            spacing: 6
            delegate: ItemDelegate {
                id: worldEntry
                required property var modelData
                width: ListView.view.width
                height: 54
                onClicked: {
                    if (controller.instances.launchWorld(modelData.instanceId, modelData.name)) {
                        controller.notify("Opening " + modelData.name + "…");
                        controller.followLaunch(modelData.instanceId);
                    }
                }
                background: Rectangle {
                    radius: 8
                    color: worldEntry.hovered ? Colors.surfaceHi : Colors.mantle
                    border.color: worldEntry.visualFocus ? Colors.accent : "transparent"
                }
                contentItem: RowLayout {
                    spacing: 12
                    ContentIcon {
                        Layout.preferredWidth: 36
                        Layout.preferredHeight: 36
                        size: 36
                        category: "saves"
                        source: worldEntry.modelData.icon || ""
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 1
                        Text {
                            Layout.fillWidth: true
                            text: worldEntry.modelData.name
                            color: Colors.text
                            font.pixelSize: 13
                            font.weight: Font.DemiBold
                            elide: Text.ElideRight
                        }
                        Text {
                            Layout.fillWidth: true
                            text: worldEntry.modelData.instanceName
                            color: Colors.subtext
                            font.pixelSize: 11
                            elide: Text.ElideRight
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: 26
                        Layout.preferredHeight: 22
                        radius: 5
                        color: worldEntry.hovered ? Colors.accent : Colors.surfaceHi
                        Text {
                            anchors.centerIn: parent
                            text: "▶"
                            font.pixelSize: 9
                            color: worldEntry.hovered ? Colors.accentInk : Colors.accent
                        }
                    }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !controller.instances.worlds.length
                text: "Your saved worlds will appear here."
                color: Colors.subtext
                font.pixelSize: 12
            }
        }
    }
}
