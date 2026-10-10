import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: screen
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        InstanceHero {
            controller: screen.controller
        }
        InstanceTabs {
            visible: screen.controller.instanceTab === "overview"
            controller: screen.controller
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.border
        }
        Item {
            id: tabContent
            Layout.fillWidth: true
            Layout.fillHeight: true
            transform: Translate { id: tabOffset }
            Connections { target: screen.controller; function onInstanceTabChanged() { tabEntrance.restart(); } }
            ParallelAnimation {
                id: tabEntrance
                NumberAnimation { target: tabContent; property: "opacity"; from: Colors.animations ? 0 : 1; to: 1; duration: Colors.animations ? 300 : 0; easing.type: Easing.OutCubic }
                NumberAnimation { target: tabOffset; property: "y"; from: Colors.animations ? 14 : 0; to: 0; duration: Colors.animations ? 380 : 0; easing.type: Easing.OutCubic }
            }
            InstanceOverview {
                controller: screen.controller
            }
            InstanceMods {
                controller: screen.controller
            }
            InstanceScreenshots {
                controller: screen.controller
            }
            InstanceFiles {
                controller: screen.controller
            }
            InstanceServers {
                controller: screen.controller
            }
            BusyIndicator {
                anchors.centerIn: parent
                running: contents.loading
                visible: running
            }
        }
    }
}
