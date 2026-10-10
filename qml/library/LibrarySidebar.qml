import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebar
    required property var controller
    signal focusBrowser
    function dropOnGroup(name) {
        const id = controller.draggingId;
        if (!id || controller.instances.groupOf(id) === name) return;
        if (controller.instances.moveToGroup(id, name))
            controller.afterGroupEdit(name ? "Moved to " + name : "Removed from group");
    }
    function focusSearch() {
        sidebarSearch.forceActiveFocus();
    }
    Layout.preferredWidth: controller.preferences.sidebarWidth
    Layout.fillHeight: true
    visible: controller.width >= 1200
    color: Colors.surface
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Colors.border
    }
    ColumnLayout {
        anchors {
            fill: parent
            margins: 12
            topMargin: 16
        }
        spacing: 16
        InstanceSearch {
            id: sidebarSearch
            Layout.fillWidth: true
            controller: sidebar.controller
            objectName: sidebar.visible ? "searchField" : "sidebarSearch"
            placeholderText: "Search instances…"
            onMoveToBrowser: sidebar.focusBrowser()
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true
            contentWidth: availableWidth
            ColumnLayout {
                width: scroll.availableWidth
                spacing: 4
                Text {
                    visible: sidebar.controller.preferences.favorites.length > 0
                    text: "— FAVORITES"
                    font.family: Colors.displayFont
                    font.pixelSize: 12
                    font.letterSpacing: 2
                    color: Colors.brass
                    Layout.topMargin: 4
                    Layout.bottomMargin: 6
                }
                Repeater {
                    model: sidebar.controller.instances.allInstances.filter(it => sidebar.controller.preferences.favorites.indexOf(it.instanceId) >= 0)
                    delegate: LibrarySidebarEntry {
                        required property var modelData
                        Layout.fillWidth: true
                        controller: sidebar.controller
                        instance: modelData
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 14
                    Text {
                        Layout.fillWidth: true
                        text: "— GROUPS"
                        font.family: Colors.displayFont
                        font.pixelSize: 12
                        font.letterSpacing: 2
                        color: Colors.brass
                    }
                    ToolButton {
                        objectName: "newGroupButton"
                        implicitWidth: 26
                        implicitHeight: 26
                        Accessible.name: "New group"
                        ToolTip.visible: hovered
                        ToolTip.delay: 400
                        ToolTip.text: "New group"
                        onClicked: sidebar.controller.newGroup("")
                        background: Rectangle { radius: 6; color: parent.hovered ? Colors.surfaceHi : "transparent" }
                        contentItem: LineIcon { name: "plus"; tint: Colors.brass; implicitWidth: 14; implicitHeight: 14 }
                    }
                }
                Repeater {
                    model: sidebar.controller.instances.groups
                    delegate: ColumnLayout {
                        id: group
                        required property var modelData
                        // Prism's own groups remember their collapsed state in instgroups.json.
                        property bool localCollapsed: false
                        readonly property bool collapsed: modelData.editable ? modelData.collapsed : localCollapsed
                        readonly property string target: modelData.editable ? modelData.name : ""
                        Layout.fillWidth: true
                        spacing: 2
                        Rectangle {
                            id: header
                            objectName: "groupHeader_" + group.modelData.name
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            implicitHeight: 30
                            radius: 6
                            color: drop.containsDrag ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16) : headerHover.hovered ? Colors.surfaceHi : "transparent"
                            border.color: drop.containsDrag ? Colors.accent : "transparent"
                            HoverHandler { id: headerHover }
                            TapHandler {
                                onTapped: {
                                    if (group.modelData.editable) sidebar.controller.instances.setGroupCollapsed(group.modelData.name, !group.collapsed);
                                    else group.localCollapsed = !group.localCollapsed;
                                }
                            }
                            TapHandler {
                                acceptedButtons: Qt.RightButton
                                enabled: group.modelData.editable
                                onTapped: groupMenu.popup()
                            }
                            RowLayout {
                                anchors { fill: parent; leftMargin: 6; rightMargin: 2 }
                                spacing: 6
                                Text {
                                    text: "›"
                                    rotation: group.collapsed ? 0 : 90
                                    color: Colors.brass
                                    font.pixelSize: 15
                                    Behavior on rotation { NumberAnimation { duration: Colors.animations ? 140 : 0 } }
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: group.modelData.name.toUpperCase()
                                    color: Colors.brass
                                    font.family: Colors.displayFont
                                    font.letterSpacing: 1.5
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: group.modelData.instances.length
                                    color: Colors.subtext
                                    font.pixelSize: 11
                                }
                                ToolButton {
                                    visible: group.modelData.editable && (headerHover.hovered || groupMenu.visible)
                                    implicitWidth: 24
                                    implicitHeight: 24
                                    Accessible.name: "Group options"
                                    onClicked: groupMenu.popup()
                                    background: Rectangle { radius: 6; color: parent.hovered ? Colors.border : "transparent" }
                                    contentItem: Text { text: "⋯"; color: Colors.subtext; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; font.pixelSize: 14 }
                                }
                            }
                            DropArea {
                                id: drop
                                anchors.fill: parent
                                keys: ["prismarine/instance"]
                                onDropped: drag => {
                                    drag.accept();
                                    sidebar.dropOnGroup(group.target);
                                }
                            }
                            ThemedMenu {
                                id: groupMenu
                                ThemedMenuItem { text: "Rename group"; onTriggered: sidebar.controller.renameGroup(group.modelData.name) }
                                ThemedMenuItem { text: "Delete group"; danger: true; onTriggered: sidebar.controller.deleteGroup(group.modelData.name) }
                            }
                        }
                        Text {
                            visible: !group.collapsed && !group.modelData.instances.length
                            Layout.fillWidth: true
                            Layout.leftMargin: 26
                            Layout.bottomMargin: 4
                            text: group.modelData.editable ? "Drag instances here" : "Every instance is in a group"
                            color: Colors.subtext
                            font.pixelSize: 12
                            font.italic: true
                        }
                        Repeater {
                            model: group.collapsed ? [] : group.modelData.instances
                            delegate: LibrarySidebarEntry {
                                required property var modelData
                                Layout.fillWidth: true
                                controller: sidebar.controller
                                instance: modelData
                                dragHost: sidebar.controller
                            }
                        }
                    }
                }
                Item {
                    Layout.preferredHeight: 16
                }
            }
        }
        Text {
            text: sidebar.controller.instances.totalCount + " instances"
            color: Colors.subtext
            font.pixelSize: 11
        }
    }
}
