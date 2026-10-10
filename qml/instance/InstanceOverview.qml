import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ScrollView {
    id: overview
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info
    anchors.fill: parent
    visible: controller.instanceTab === "overview"
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: overview.availableWidth - 64
        x: 32
        spacing: 20
        Item {
            Layout.preferredHeight: 4
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            InstanceInfoPanel {
                controller: overview.controller
                panelWidth: overview.width
            }
            InstanceQuickSettings {
                Layout.fillHeight: true
                Layout.preferredWidth: Math.max(280, overview.width * 0.29)
                controller: overview.controller
                panelWidth: overview.width
                onChooseCover: controller.editArtwork(contents.instanceId)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 20
            InstalledModsPanel {
                controller: overview.controller
                panelWidth: overview.width
            }
            InstanceNotesPanel {
                Layout.preferredWidth: Math.max(280, overview.width * 0.29)
                controller: overview.controller
                panelWidth: overview.width
            }
        }
        Item {
            Layout.preferredHeight: 24
        }
    }
}
