import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One instance in Settings → Storage; expands to its categories and worlds.
Rectangle {
    id: row
    required property var host
    required property var entry
    property real largest: 1
    property bool expanded: false
    property var selected: []
    readonly property var info: host.controller.instances.getById(entry.instanceId)
    readonly property var cleanableParts: entry.categories.filter(it => it.cleanable && it.size > 0)
    readonly property real cleanableSize: entry.categories.filter(it => host.cleanableKeys.indexOf(it.key) >= 0).reduce((total, it) => total + it.size, 0)
    implicitHeight: body.implicitHeight + 24
    radius: 12
    color: Colors.surface
    border.color: expanded ? Colors.accent : Colors.border
    ColumnLayout {
        id: body
        anchors { fill: parent; margins: 12; leftMargin: 14; rightMargin: 14 }
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            InstanceIcon {
                size: 34
                icon: row.info.icon || ""
                name: row.entry.name
                loader: row.info.loader || ""
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 6
                RowLayout {
                    Layout.fillWidth: true
                    Text { Layout.fillWidth: true; text: row.entry.name; color: Colors.text; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text {
                        visible: row.cleanableSize > 0
                        text: Colors.formatBytes(row.cleanableSize) + " cleanable"
                        color: Colors.subtext
                        font.pixelSize: 12
                    }
                    Text { text: Colors.formatBytes(row.entry.total); color: Colors.text; font.pixelSize: 14; font.weight: Font.DemiBold; Layout.leftMargin: 10 }
                }
                // Bars share one scale, so the biggest instance spans the full width.
                Item {
                    Layout.fillWidth: true
                    implicitHeight: 8
                    StorageBar {
                        width: Math.max(12, parent.width * row.entry.total / Math.max(1, row.largest))
                        height: 8
                        barHeight: 8
                        segments: row.host.instanceSegments(row.entry.categories)
                    }
                }
            }
            ToolButton {
                implicitWidth: 34
                implicitHeight: 34
                Accessible.name: row.expanded ? "Hide details" : "Show details"
                onClicked: row.expanded = !row.expanded
                background: Rectangle { radius: 17; color: parent.hovered ? Colors.surfaceHi : "transparent" }
                contentItem: Text {
                    text: "›"
                    rotation: row.expanded ? 90 : 0
                    Behavior on rotation { NumberAnimation { duration: Colors.animations ? 160 : 0 } }
                    color: Colors.subtext
                    font.pixelSize: 20
                    horizontalAlignment: Text.AlignHCenter
                    verticalAlignment: Text.AlignVCenter
                }
            }
        }
        TapHandler { onTapped: row.expanded = !row.expanded }
        GridLayout {
            Layout.fillWidth: true
            visible: row.expanded
            columns: row.width >= 720 ? 2 : 1
            columnSpacing: 24
            rowSpacing: 12
            // Category table: the accessible readout of the bar above.
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2
                Text { text: "WHAT'S INSIDE"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 11; font.letterSpacing: 2; Layout.bottomMargin: 4 }
                Repeater {
                    model: row.entry.categories.filter(it => it.size > 0)
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 8
                        TickBox {
                            visible: modelData.cleanable
                            checked: row.selected.indexOf(modelData.key) >= 0
                            Accessible.name: "Clean " + modelData.label
                            onToggled: row.selected = checked ? row.selected.concat([modelData.key]) : row.selected.filter(it => it !== modelData.key)
                        }
                        Item { visible: !modelData.cleanable; implicitWidth: 18 }
                        Text { Layout.fillWidth: true; text: modelData.label; color: Colors.text; font.pixelSize: 13; elide: Text.ElideRight }
                        Text { text: Colors.formatBytes(modelData.size); color: Colors.subtext; font.pixelSize: 13 }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    Layout.topMargin: 8
                    spacing: 10
                    ActionButton {
                        text: row.selected.length ? "Clean selected" : "Select items to clean"
                        danger: row.selected.length > 0
                        enabled: row.selected.length > 0
                        onClicked: row.host.askClean(row.entry, row.selected)
                    }
                    TextLink {
                        visible: row.cleanableParts.length > 0
                        text: "Select logs & caches"
                        pixelSize: 13
                        onClicked: row.selected = row.cleanableParts.filter(it => ["logs", "caches", "removed"].indexOf(it.key) >= 0).map(it => it.key)
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.alignment: Qt.AlignTop
                spacing: 2
                Text { text: "WORLDS"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 11; font.letterSpacing: 2; Layout.bottomMargin: 4 }
                Text { visible: !row.entry.worlds.length; text: "No worlds yet."; color: Colors.subtext; font.pixelSize: 13 }
                Repeater {
                    model: row.entry.worlds
                    delegate: RowLayout {
                        required property var modelData
                        Layout.fillWidth: true
                        Layout.preferredHeight: 30
                        spacing: 8
                        LineIcon { name: "world"; tint: Colors.subtext; implicitWidth: 16; implicitHeight: 16 }
                        Text { Layout.fillWidth: true; text: modelData.name; color: Colors.text; font.pixelSize: 13; elide: Text.ElideRight }
                        Text { text: Colors.formatBytes(modelData.size); color: Colors.subtext; font.pixelSize: 13 }
                        TextLink {
                            text: "Trash"
                            tint: Colors.danger
                            pixelSize: 12
                            Accessible.name: "Move " + modelData.name + " to the trash"
                            onClicked: row.host.askTrashWorld(row.entry, modelData)
                        }
                    }
                }
            }
        }
    }
}
