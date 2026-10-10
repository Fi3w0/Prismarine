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
        Text {
            text: "Your stats"
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: 20
            font.letterSpacing: 2
        }
        GridLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            columns: 2
            rowSpacing: 10
            columnSpacing: 10
            Repeater {
                model: [
                    {
                        value: controller.instances.summary.totalPlayed,
                        label: "total playtime"
                    },
                    {
                        value: controller.instances.totalCount,
                        label: "instances"
                    },
                    {
                        value: controller.instances.summary.totalMods,
                        label: "enabled mods"
                    },
                    {
                        value: controller.instances.summary.mostPlayed,
                        label: "most played"
                    }
                ]
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: Colors.surfaceHi
                    radius: 10
                    Column {
                        anchors {
                            fill: parent
                            margins: 14
                        }
                        spacing: 8
                        Text {
                            width: parent.width
                            text: modelData.value
                            color: Colors.accent
                            font.pixelSize: 23
                            font.weight: Font.ExtraBold
                            elide: Text.ElideRight
                        }
                        Text {
                            text: modelData.label
                            color: Colors.subtext
                            font.pixelSize: 12
                        }
                    }
                }
            }
        }
    }
}
