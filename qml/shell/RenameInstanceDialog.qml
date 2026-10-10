import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MotionDialog {
    id: dialog
    objectName: "renameInstanceDialog"
    required property var controller
    property string instanceId: ""
    property string originalName: ""
    property string error: ""
    function openFor(id) {
        const info = controller.instances.getById(id);
        if (!info.instanceId) return;
        instanceId = id;
        originalName = info.name;
        nameField.text = originalName;
        error = "";
        open();
    }
    function save() {
        if (!nameField.text.trim()) return;
        if (!controller.instances.renameInstance(instanceId, nameField.text, originalName)) return;
        if (controller.details.instanceId === instanceId) controller.details.refresh();
        controller.notify("Instance renamed");
        close();
    }
    title: "Rename instance"
    width: Math.min(440, controller.width - 64)
    modal: true
    closePolicy: Popup.CloseOnEscape
    onOpened: { nameField.forceActiveFocus(); nameField.selectAll(); }
    Connections {
        target: dialog.controller.instances
        function onErrorOccurred(message) { if (dialog.visible) dialog.error = message; }
    }
    contentItem: ColumnLayout {
        spacing: 12
        InputField {
            id: nameField
            objectName: "renameInstanceInput"
            Layout.fillWidth: true
            placeholderText: "Instance name"
            Accessible.name: "Instance name"
            onTextEdited: dialog.error = ""
            onAccepted: dialog.save()
            Keys.onEscapePressed: dialog.close()
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
        confirmText: "Rename"
        confirmWidth: 130
        confirmEnabled: !!nameField.text.trim()
        onCancelled: dialog.close()
        onConfirmed: dialog.save()
    }
}
