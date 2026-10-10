import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Keyboard- and compact-window-friendly alternative to dragging in the sidebar.
MotionDialog {
    id: dialog
    objectName: "moveToGroupDialog"
    required property var controller
    property string instanceId: ""
    property string currentGroup: ""
    property var names: []
    function openFor(id) {
        instanceId = id;
        currentGroup = controller.instances.groupOf(id);
        names = controller.instances.groupNames();
        open();
    }
    function choose(group) {
        if (group === currentGroup) { close(); return; }
        if (!controller.instances.moveToGroup(instanceId, group)) return;
        close();
        controller.afterGroupEdit(group ? "Moved to " + group : "Removed from " + currentGroup);
    }
    title: "Move to group"
    subtitle: controller.instances.getById(instanceId).name || ""
    width: Math.min(440, controller.width - 64)
    modal: true
    component Choice: ItemDelegate {
        id: choice
        property bool current: false
        property string glyph: "folder"
        Layout.fillWidth: true
        implicitHeight: 44
        background: Rectangle {
            radius: 10
            color: choice.current ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12) : choice.hovered || choice.visualFocus ? Colors.surfaceHi : "transparent"
            border.color: choice.current ? Colors.accent : choice.visualFocus ? Colors.border : "transparent"
        }
        contentItem: RowLayout {
            spacing: 12
            LineIcon { name: choice.glyph; tint: choice.current ? Colors.accent : Colors.subtext; implicitWidth: 18; implicitHeight: 18 }
            Text { Layout.fillWidth: true; text: choice.text; color: Colors.text; font.pixelSize: 14; elide: Text.ElideRight }
            Text { visible: choice.current; text: "Current"; color: Colors.accent; font.pixelSize: 12 }
        }
    }
    contentItem: ColumnLayout {
        spacing: 2
        ScrollView {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(choices.implicitHeight, 320)
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                id: choices
                width: parent.width
                spacing: 2
                Repeater {
                    model: dialog.names
                    delegate: Choice {
                        required property string modelData
                        text: modelData
                        current: modelData === dialog.currentGroup
                        onClicked: dialog.choose(modelData)
                    }
                }
                Choice {
                    text: "No group"
                    glyph: "list"
                    current: !dialog.currentGroup
                    onClicked: dialog.choose("")
                }
            }
        }
        Choice {
            Layout.topMargin: 6
            text: "New group…"
            glyph: "plus"
            onClicked: { dialog.close(); dialog.controller.newGroup(dialog.instanceId); }
        }
    }
}
