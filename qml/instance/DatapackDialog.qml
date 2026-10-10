import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

MotionDialog {
    id: dialog
    objectName: "datapackDialog"
    required property var controller
    property string world: ""
    property var entries: []
    function openFor(name) { world = name; refresh(); open(); }
    function refresh() { entries = controller.details.datapacks(world); }
    title: "Datapacks · " + world
    modal: true
    width: Math.min(700, controller.width - 64)
    standardButtons: Dialog.Close
    background: Rectangle { color: Colors.surface; radius: 12; border.color: Colors.border }
    Connections { target: dialog.controller.details; function onChanged() { if (dialog.visible) dialog.refresh(); } }
    contentItem: ColumnLayout {
        spacing: 14
        Text { Layout.fillWidth: true; text: "Datapacks belong to this world. Restart the world after making changes."; color: Colors.subtext; wrapMode: Text.Wrap }
        RowLayout {
            ActionButton { text: "Browse datapacks"; onClicked: { dialog.close(); dialog.controller.browseDatapacks(dialog.controller.details.instanceId, dialog.world); } }
            ActionButton { text: "Add ZIP…"; onClicked: picker.open() }
        }
        ListView {
            id: packs
            Layout.fillWidth: true; Layout.preferredHeight: Math.min(250, Math.max(60, count * 48))
            clip: true; model: dialog.entries; ScrollBar.vertical: ScrollBar {}
            delegate: RowLayout {
                required property var modelData
                width: packs.width; height: 48
                Text { Layout.fillWidth: true; text: modelData.fileName; color: Colors.text; elide: Text.ElideMiddle }
                ActionButton { text: "Remove"; implicitHeight: 32; onClicked: { remove.packName = modelData.fileName; remove.open(); } }
            }
            Text { anchors.centerIn: parent; visible: !packs.count; text: "No datapacks installed"; color: Colors.subtext }
        }
        ContentUpdates { controller: dialog.controller; contentType: "datapack"; world: dialog.world }
    }
    FileDialog {
        id: picker; title: "Add datapacks"; fileMode: FileDialog.OpenFiles; nameFilters: ["Datapacks (*.zip)"]
        onAccepted: { dialog.controller.details.addDatapacks(dialog.world, selectedFiles); dialog.refresh(); }
    }
    ConfirmDialog {
        id: remove; property string packName: ""
        anchors.centerIn: Overlay.overlay
        title: "Remove datapack?"; message: packName + " will be moved to the trash or kept in the world's removed-files folder."
        confirmText: "Remove"; danger: true
        onConfirmed: { dialog.controller.details.removeDatapack(dialog.world, packName); dialog.refresh(); }
    }
}
