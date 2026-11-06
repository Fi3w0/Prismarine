import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MotionDialog {
    id: dialog
    objectName: "installReviewDialog"
    required property var controller
    readonly property var installer: controller.installer
    property string retryInstanceId: ""
    property string repairProject: ""
    property string repairDetail: ""
    title: "Review installation"
    width: Math.min(680, controller.width - 80)
    height: Math.min(implicitHeight, controller.height - 64)
    modal: true
    standardButtons: Dialog.Close
    onClosed: {
        if (installer.state !== "complete") installer.cancel();
        retryInstanceId = "";
        repairProject = "";
        repairDetail = "";
    }
    background: Rectangle {
        radius: 12
        color: Colors.surface
        border.color: Colors.border
    }
    contentItem: ScrollView {
        id: reviewScroll
        implicitHeight: installContent.implicitHeight
        contentWidth: availableWidth
        contentHeight: installContent.implicitHeight
        clip: true
        ColumnLayout {
            id: installContent
            width: reviewScroll.availableWidth
            spacing: 16
            Text {
                text: "Selected content & dependencies"
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: Typography.emptyTitle
            }
            Text {
                Layout.fillWidth: true
                text: "Install into " + (dialog.controller.instances.getById(dialog.installer.instanceId).name || "instance") +
                      (dialog.installer.world ? " · " + dialog.installer.world : "")
                color: Colors.subtext
                wrapMode: Text.Wrap
                font.pixelSize: Typography.body
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
                        font.pixelSize: Typography.bodyLarge
                        elide: Text.ElideRight
                    }
                    Text {
                        width: parent.width
                        text: modelData.filename
                        color: Colors.subtext
                        font.pixelSize: Typography.bodySmall
                        elide: Text.ElideMiddle
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: !!dialog.retryInstanceId && dialog.installer.state !== "complete"
                text: (dialog.repairDetail ? qsTr("Loader requirement: %1\n\n").arg(dialog.repairDetail) : "")
                    + qsTr("This release matches your Minecraft and loader versions. Check the required version before confirming.")
                textFormat: Text.PlainText
                color: Colors.subtext
                font.pixelSize: Typography.bodySmall
                wrapMode: Text.Wrap
                maximumLineCount: 6
                elide: Text.ElideRight
            }
            TextLink {
                objectName: "chooseRepairVersion"
                visible: !!dialog.retryInstanceId && dialog.installer.state !== "downloading" && dialog.installer.state !== "complete"
                text: qsTr("Choose a version in Browse →")
                onClicked: {
                    const id = dialog.retryInstanceId, project = dialog.repairProject;
                    dialog.close();
                    dialog.controller.catalog.provider = "modrinth";
                    dialog.controller.browseFor(id, project);
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
                font.pixelSize: Typography.body
            }
            ActionButton {
                objectName: "installFixLaunch"
                Layout.fillWidth: true
                text: qsTr("Launch again")
                primary: true
                visible: dialog.installer.state === "complete" && !!dialog.retryInstanceId
                onClicked: {
                    const id = dialog.retryInstanceId, name = dialog.controller.instances.getById(id).name || id;
                    dialog.close();
                    dialog.controller.play(id, name);
                }
            }
            ActionButton {
                objectName: "confirmInstallation"
                Layout.fillWidth: true
                text: "Confirm installation"
                primary: true
                visible: dialog.installer.state !== "complete"
                enabled: dialog.installer.state === "ready"
                onClicked: dialog.installer.install()
            }
        }
    }
}
