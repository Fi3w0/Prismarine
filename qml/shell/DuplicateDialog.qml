import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MotionDialog {
    id: dialog
    objectName: "duplicateDialog"
    required property var controller
    property string instanceId: ""
    property var choices: ({})
    function openFor(id) {
        if (controller.creator.loading) return;
        instanceId = id;
        copyName.text = (controller.instances.getById(id).name || "Instance") + " (copy)";
        choices = {worlds: true, mods: true, resources: true, screenshots: false, options: true, servers: true, playtime: false};
        open();
    }
    title: "Duplicate instance"
    subtitle: "Choose what to copy. Stop the game first so the copy includes complete saves."
    modal: true
    width: Math.min(560, controller.width - 64)
    closePolicy: controller.creator.loading ? Popup.NoAutoClose : Popup.CloseOnEscape
    Connections {
        target: dialog.controller.creator
        function onDuplicated(id) {
            if (!dialog.visible) return;
            dialog.close(); dialog.controller.openInstance(id); dialog.controller.notify("Instance duplicated");
        }
    }
    contentItem: ColumnLayout {
        spacing: 12
        Text { text: "NAME"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 12; font.letterSpacing: 2 }
        InputField { id: copyName; Layout.fillWidth: true; placeholderText: "Copy name"; enabled: !dialog.controller.creator.loading }
        Text { text: "INCLUDE"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 12; font.letterSpacing: 2; Layout.topMargin: 6 }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            rowSpacing: 6
            columnSpacing: 16
            Repeater {
                model: [{key: "worlds", label: "Worlds"}, {key: "mods", label: "Mods"}, {key: "resources", label: "Resource packs and shaders"}, {key: "screenshots", label: "Screenshots"}, {key: "options", label: "Game options"}, {key: "servers", label: "Server list"}, {key: "playtime", label: "Keep total playtime"}]
                delegate: ToggleSwitch {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.label
                    checked: !!dialog.choices[modelData.key]
                    enabled: !dialog.controller.creator.loading
                    onToggled: { let next = Object.assign({}, dialog.choices); next[modelData.key] = checked; dialog.choices = next; }
                }
            }
        }
        Text { Layout.fillWidth: true; text: dialog.controller.creator.error; visible: !!text; color: Colors.danger; wrapMode: Text.Wrap }
    }
    footer: DialogActions {
        cancelVisible: !dialog.controller.creator.loading
        confirmText: dialog.controller.creator.loading ? "Copying…" : "Create copy"
        confirmEnabled: !dialog.controller.creator.loading && !!copyName.text.trim()
        onCancelled: dialog.close()
        onConfirmed: dialog.controller.creator.duplicate(dialog.instanceId, copyName.text, dialog.choices)
    }
}
