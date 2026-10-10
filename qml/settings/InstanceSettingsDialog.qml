import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MotionDialog {
    id: dialog
    objectName: "instanceSettingsDialog"
    required property var controller
    title: "Instance settings"
    modal: true
    width: Math.min(760, controller.width - 80)
    height: Math.min(780, controller.height - 64)
    footer: Item {
        implicitHeight: 64
        RowLayout {
            anchors {
                fill: parent
                margins: 12
            }
            Item {
                Layout.fillWidth: true
            }
            ActionButton {
                text: "Cancel"
                onClicked: dialog.close()
            }
            ActionButton {
                objectName: "saveInstanceSettings"
                text: "Save settings"
                primary: true
                onClicked: settingsForm.save()
            }
        }
    }
    background: Rectangle {
        color: Colors.surface
        radius: 12
        border.color: Colors.border
    }
    contentItem: ScrollView {
        id: scroll
        objectName: "instanceSettingsScroll"
        clip: true
        contentWidth: availableWidth
        LaunchSettingsForm {
            id: settingsForm
            showSaveButton: false
            width: scroll.availableWidth - 24
            javaManager: dialog.controller.javaManager
            service: dialog.controller.launchSettings
            accounts: dialog.controller.instances.accounts
            onSaved: {
                dialog.controller.details.refresh();
                dialog.controller.notify("Instance settings saved");
                dialog.close();
            }
        }
    }
}
