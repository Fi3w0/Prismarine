import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: control
    required property var controller
    required property string contentType
    property string world: ""
    readonly property var updater: controller.updater
    readonly property bool matches: !!updater && updater.instanceId === controller.details.instanceId && updater.contentType === contentType && updater.world === world
    readonly property var updates: matches ? updater.updates : []
    Layout.fillWidth: true
    visible: !!updater
    RowLayout {
        Layout.fillWidth: true
        ActionButton {
            text: control.matches && control.updater.state === "checking" ? "Checking…" : "Check for updates"
            enabled: !!control.updater && control.updater.state !== "checking" && control.updater.state !== "updating"
            onClicked: control.updater.check(control.controller.details.instanceId, control.contentType, control.world)
        }
        Text {
            Layout.fillWidth: true; color: Colors.subtext; wrapMode: Text.Wrap
            text: control.matches && control.updater.state === "ready" ? (control.updates.length ? control.updates.length + " updates available" : "No Modrinth updates found") : ""
        }
        ActionButton { text: "Review updates"; visible: control.updates.length > 0; onClicked: review.open() }
    }
    Text { Layout.fillWidth: true; visible: control.matches && !!text; text: control.matches ? control.updater.error : ""; color: Colors.danger; wrapMode: Text.Wrap }
    MotionDialog {
        id: review
        title: "Content updates"
        anchors.centerIn: Overlay.overlay
        width: Math.min(640, control.controller.width - 64)
        modal: true
        standardButtons: Dialog.Close
        background: Rectangle { color: Colors.surface; radius: 12; border.color: Colors.border }
        contentItem: ColumnLayout {
            Text { Layout.fillWidth: true; text: "Stop Minecraft before updating content. Previous files are kept in the trash or the instance's removed-files folder."; color: Colors.subtext; wrapMode: Text.Wrap }
            ListView {
                Layout.fillWidth: true; Layout.preferredHeight: Math.min(300, count * 52)
                clip: true; model: control.updates; ScrollBar.vertical: ScrollBar {}
                delegate: Column {
                    required property var modelData
                    width: ListView.view.width; height: 52
                    Text { width: parent.width; text: modelData.fileName; color: Colors.text; elide: Text.ElideMiddle }
                    Text { width: parent.width; text: "→ " + modelData.newFileName; color: Colors.accent; elide: Text.ElideMiddle }
                }
            }
            ProgressBar { Layout.fillWidth: true; value: control.updater ? control.updater.progress : 0; visible: !!control.updater && control.updater.state === "updating" }
            Text { Layout.fillWidth: true; text: control.updater ? control.updater.error : ""; visible: !!text; color: Colors.danger; wrapMode: Text.Wrap }
            ActionButton {
                Layout.fillWidth: true; primary: true
                text: control.updater && control.updater.state === "updating" ? "Updating…" : "Update all"
                enabled: control.matches && control.updater.state === "ready" && control.updates.length > 0
                onClicked: control.updater.update([])
            }
        }
    }
}
