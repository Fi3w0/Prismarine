import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MotionDialog {
    id: dialog
    required property var controller
    readonly property var installer: controller.installer
    title: "Review installation"
    width: Math.min(680, controller.width - 80)
    modal: true
    standardButtons: Dialog.Close
    onClosed: if (installer.state !== "complete")
        installer.cancel()
    background: Rectangle {
        radius: 12
        color: Colors.surface
        border.color: Colors.border
    }
    contentItem: ColumnLayout {
        spacing: 16
        Text {
            text: "Selected content & dependencies"
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: 24
        }
        Text {
            Layout.fillWidth: true
            text: "Install into " + (dialog.controller.instances.getById(dialog.installer.instanceId).name || "instance") +
                  (dialog.installer.world ? " · " + dialog.installer.world : "")
            color: Colors.subtext
            wrapMode: Text.Wrap
            font.pixelSize: 13
        }
        ListView {
            id: files
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(320, dialog.installer.plan.length * 48)
            clip: true
            model: dialog.installer.plan
            ScrollBar.vertical: ScrollBar {}
            delegate: Column {
                required property var modelData
                width: files.width
                height: 48
                spacing: 4
                Text {
                    width: parent.width
                    text: (modelData.dependency ? "↳  " : "") + modelData.name
                    color: Colors.text
                    font.pixelSize: 15
                    elide: Text.ElideRight
                }
                Text {
                    width: parent.width
                    text: modelData.filename
                    color: Colors.subtext
                    font.pixelSize: 12
                    elide: Text.ElideMiddle
                }
            }
        }
        BusyIndicator {
            running: dialog.installer.state === "resolving"
            visible: running
        }
        ProgressBar {
            Layout.fillWidth: true
            from: 0
            to: 1
            value: dialog.installer.progress
            visible: dialog.installer.state === "downloading"
        }
        Text {
            Layout.fillWidth: true
            text: dialog.installer.error
            visible: !!text
            color: Colors.danger
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            text: dialog.installer.state === "complete" ? "Installed. Your content is ready for the next launch." : "Downloads are verified before installation. Existing files are preserved."
            color: Colors.subtext
            wrapMode: Text.Wrap
            font.pixelSize: 13
        }
        ActionButton {
            Layout.fillWidth: true
            text: "Confirm installation"
            primary: true
            visible: dialog.installer.state !== "complete"
            enabled: dialog.installer.state === "ready"
            onClicked: dialog.installer.install()
        }
    }
}
