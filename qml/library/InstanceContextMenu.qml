import QtQuick
import QtQuick.Controls

// Right-click menu for an instance card, row or sidebar entry.
ThemedMenu {
    id: menu
    required property var controller
    property string instanceId: ""
    property string name: ""
    function openFor(id, label) {
        instanceId = id;
        name = label;
        popup();
    }
    ThemedMenuItem { text: "Play"; onTriggered: menu.controller.play(menu.instanceId, menu.name) }
    ThemedMenuItem { text: "Open instance"; onTriggered: menu.controller.openInstance(menu.instanceId) }
    MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Colors.border } }
    ThemedMenuItem { text: "Rename"; hint: "F2"; onTriggered: menu.controller.renameInstance(menu.instanceId) }
    ThemedMenuItem { text: "Move to group…"; onTriggered: menu.controller.moveToGroup(menu.instanceId) }
    ThemedMenuItem { text: "Card & banner images…"; onTriggered: menu.controller.editArtwork(menu.instanceId) }
    ThemedMenuItem { text: "Duplicate"; onTriggered: menu.controller.duplicateInstance(menu.instanceId) }
    ThemedMenuItem { text: "Instance settings"; onTriggered: menu.controller.editSettings(menu.instanceId) }
    MenuSeparator { contentItem: Rectangle { implicitHeight: 1; color: Colors.border } }
    ThemedMenuItem { text: "Open folder"; onTriggered: menu.controller.instances.openFolder(menu.instanceId) }
    ThemedMenuItem { text: "Export or share"; visible: !!menu.controller.packExporter; height: visible ? implicitHeight : 0; onTriggered: menu.controller.exportInstance(menu.instanceId) }
}
