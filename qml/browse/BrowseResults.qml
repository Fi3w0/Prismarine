import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: panel
    required property var controller
    property real preferredPanelWidth: 400
    property var selectedProject: ({})
    property string targetId: ""
    property string contentType: "mod"
    signal projectSelected(var project)
    signal apiKeyRequested()
    signal prismInstallRequested()
    readonly property bool needsApiKey: controller.catalog.provider === "curseforge" && !controller.catalog.curseForgeReady

    Layout.preferredWidth: preferredPanelWidth
    Layout.fillHeight: true
    radius: 14
    color: Colors.surface
    border.color: Colors.border
    ListView {
        id: results
        anchors {
            fill: parent
            margins: 10
        }
        model: controller.catalog.results
        clip: true
        spacing: 6
        ScrollBar.vertical: ScrollBar {}
        delegate: ItemDelegate {
            id: result
            required property var modelData
            objectName: "browseResult_" + modelData.project_id
            width: results.width
            height: 64
            onClicked: projectSelected(modelData)
            background: Rectangle {
                radius: 8
                color: result.hovered || selectedProject.project_id === result.modelData.project_id ? Colors.surfaceHi : "transparent"
            }
            contentItem: RowLayout {
                spacing: 12
                Image {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    source: result.modelData.icon_url || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Text {
                        Layout.fillWidth: true
                        text: result.modelData.title
                        color: Colors.text
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: result.modelData.description
                        color: Colors.subtext
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                }
                Text { text: "✓"; visible: controller.downloads.contains(targetId, contentType, result.modelData.project_id); color: Colors.accent; font.pixelSize: 18 }
            }
        }
        BusyIndicator {
            anchors.centerIn: parent
            running: controller.catalog.loading
            visible: running
        }
        ColumnLayout {
            anchors.centerIn: parent
            width: parent.width - 24
            visible: !controller.catalog.loading && !controller.catalog.results.length
            spacing: 16
            Text {
                Layout.fillWidth: true
                text: panel.needsApiKey ? "Install CurseForge content through Prism Launcher without adding an API key here, or add a key to browse in Prismarine."
                                       : controller.catalog.error || "No matching projects. Try another search."
                color: Colors.subtext
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            ActionButton {
                objectName: "browseInstallCurseForgeInPrism"
                Layout.alignment: Qt.AlignHCenter
                visible: panel.needsApiKey && panel.contentType !== "datapack"
                enabled: panel.contentType === "modpack" || !!panel.targetId
                primary: true
                text: "Install with Prism Launcher…"
                onClicked: panel.prismInstallRequested()
            }
            Text {
                Layout.fillWidth: true
                visible: panel.needsApiKey
                text: panel.contentType === "modpack" ? "In Prism: Add Instance → CurseForge."
                    : panel.contentType === "datapack" ? "Download datapacks from CurseForge's website, then drop the file into Prismarine."
                    : !panel.targetId ? "Select an instance first to install content with Prism."
                    : "In Prism: " + ({mod: "Mods", resourcepack: "Resource packs", shader: "Shader packs"})[panel.contentType]
                      + " → Download → CurseForge."
                color: Colors.subtext
                font.pixelSize: 12
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }
            TextLink {
                Layout.alignment: Qt.AlignHCenter
                visible: panel.needsApiKey && panel.contentType === "datapack"
                text: "Browse CurseForge datapacks"
                onClicked: Qt.openUrlExternally("https://www.curseforge.com/minecraft/search?class=data-packs")
            }
            ActionButton {
                objectName: "browseAddCurseForgeKey"
                Layout.alignment: Qt.AlignHCenter
                visible: panel.needsApiKey
                text: "Add API key…"
                onClicked: panel.apiKeyRequested()
            }
        }
    }
}
