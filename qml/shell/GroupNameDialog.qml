import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Names a new group or renames one. A new group can receive an instance straight away.
MotionDialog {
    id: dialog
    objectName: "groupNameDialog"
    required property var controller
    property string originalName: ""
    property string moveInstanceId: ""
    property string error: ""
    function openFor(name, instanceId) {
        originalName = name || "";
        moveInstanceId = instanceId || "";
        nameField.text = originalName;
        error = "";
        open();
    }
    function save() {
        const name = nameField.text.trim();
        if (!name) return;
        const instances = controller.instances;
        const ok = originalName ? instances.renameGroup(originalName, name) : instances.createGroup(name);
        if (!ok) return;
        if (moveInstanceId && !instances.moveToGroup(moveInstanceId, name)) return;
        close();
        controller.afterGroupEdit(originalName ? "Group renamed" : moveInstanceId ? "Moved to " + name : "Group created");
    }
    title: originalName ? "Rename group" : "New group"
    subtitle: originalName ? "Instances stay in the group under its new name."
                           : moveInstanceId ? "Create a group and move " + (controller.instances.getById(moveInstanceId).name || "this instance") + " into it."
                           : "Groups are shared with Prism Launcher. Drag instances onto a group in the sidebar to fill it."
    width: Math.min(460, controller.width - 64)
    modal: true
    onOpened: { nameField.forceActiveFocus(); nameField.selectAll(); }
    Connections {
        target: dialog.controller.instances
        function onErrorOccurred(message) { if (dialog.visible) dialog.error = message; }
    }
    contentItem: ColumnLayout {
        spacing: 10
        InputField {
            id: nameField
            objectName: "groupNameInput"
            Layout.fillWidth: true
            placeholderText: "Group name"
            Accessible.name: "Group name"
            maximumLength: 80
            onTextEdited: dialog.error = ""
            onAccepted: dialog.save()
        }
        Text {
            Layout.fillWidth: true
            visible: !!dialog.error
            text: dialog.error
            textFormat: Text.PlainText
            color: Colors.danger
            wrapMode: Text.Wrap
        }
    }
    footer: DialogActions {
        confirmName: "saveGroup"
        confirmText: dialog.originalName ? "Rename" : "Create"
        confirmWidth: 130
        confirmEnabled: !!nameField.text.trim()
        onCancelled: dialog.close()
        onConfirmed: dialog.save()
    }
}
