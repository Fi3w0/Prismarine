import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info
    property real panelWidth: width

    Layout.fillWidth: true
    Layout.preferredHeight: 188
    radius: 12
    color: Colors.surface
    border.color: Colors.border
    ColumnLayout {
        anchors {
            fill: parent
            margins: 20
        }
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            Text {
                text: "Installed mods"
                font.family: Colors.displayFont
                font.pixelSize: 20
                font.letterSpacing: 2
                color: Colors.bone
            }
            TextLink {
                text: "All " + (controller.details.info.mods || 0) + " mods →"
                onClicked: controller.openTab("mods")
            }
            Item {
                Layout.fillWidth: true
            }
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: panelWidth < 1100 ? 2 : 3
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: contents.mods.slice(0, 6)
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    radius: 8
                    color: Colors.surfaceHi
                    RowLayout {
                        anchors {
                            fill: parent
                            margins: 10
                        }
                        spacing: 10
                        ContentIcon {
                            size: 32
                            source: modelData.icon || ""
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 3
                            Text {
                                Layout.fillWidth: true
                                text: modelData.name
                                color: Colors.text
                                font.pixelSize: 12
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                text: modelData.version
                                color: Colors.subtext
                                font.pixelSize: 11
                            }
                        }
                    }
                }
            }
        }
        Text {
            visible: !contents.loading && !contents.mods.length
            text: "No mods installed. Browse content to find your next addition."
            color: Colors.subtext
            font.pixelSize: 12
        }
    }
}
