import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: panel
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info
    property real panelWidth: width
    Layout.fillWidth: true
    // Grows when the update row appears, so nothing spills past the border.
    Layout.preferredHeight: Math.max(292, rows.implicitHeight + 36)
    radius: 12
    color: Colors.surface
    border.color: Colors.border
    ColumnLayout {
        id: rows
        anchors {
            fill: parent
            margins: 18
        }
        spacing: 10
        Text {
            text: "Ready to play"
            font.family: Colors.displayFont
            font.pixelSize: 20
            font.letterSpacing: 2
            color: Colors.bone
        }
        Repeater {
            model: [
                {
                    mark: info.javaAvailable ? "✓" : "i",
                    text: info.javaAvailable ? "Java executable found" : info.javaPath ? "Java executable needs attention" : "Java will be selected automatically",
                    detail: info.javaAvailable ? "Configured runtime" : "Java settings"
                },
                {
                    mark: "✓",
                    text: "Minecraft " + (info.version || "—") + " · " + (info.loader || "") + " " + (info.loaderVersion || ""),
                    detail: "Version manifest"
                },
                {
                    mark: "i",
                    text: (info.enabledMods || 0) + " enabled mods · " + (info.disabledMods || 0) + " disabled",
                    detail: info.unreadableMods ? info.unreadableMods + " metadata unavailable" : "Metadata read"
                },
                {
                    mark: "i",
                    text: "GameMode " + (info.gameMode ? "on" : "off") + " · MangoHud " + (info.mangoHud ? "on" : "off"),
                    detail: "Performance"
                }
            ]
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 40
                radius: 8
                color: Colors.inset
                RowLayout {
                    anchors {
                        fill: parent
                        margins: 12
                    }
                    spacing: 12
                    Text {
                        text: modelData.mark
                        color: modelData.mark === "✓" ? Colors.success : Colors.brass
                        font.pixelSize: 14
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.text
                        color: Colors.text
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                    Text {
                        text: modelData.detail
                        color: Colors.subtext
                        font.pixelSize: 11
                        visible: panel.width > 660
                    }
                }
            }
        }
        Rectangle {
            readonly property var updater: panel.controller.updater
            readonly property int count: updater && updater.contentType === "mod" && updater.instanceId === panel.controller.details.instanceId ? updater.updates.length : 0
            Layout.fillWidth: true
            implicitHeight: 40
            visible: count > 0
            radius: 8
            color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.08)
            border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.45)
            RowLayout {
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 12
                Text {
                    text: "↑"
                    color: Colors.accent
                    font.pixelSize: 14
                }
                Text {
                    Layout.fillWidth: true
                    text: parent.parent.count + (parent.parent.count === 1 ? " mod has an update" : " mods have updates") + " on Modrinth"
                    color: Colors.text
                    font.pixelSize: 13
                    elide: Text.ElideRight
                }
                TextLink {
                    text: "Review updates"
                    onClicked: panel.controller.openTab("mods")
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
    }
}
