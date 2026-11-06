import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: worlds
    required property var controller
    required property string instanceId
    readonly property var entries: controller.instances.worlds.filter(world => world.instanceId === instanceId).slice(0, 3)
    spacing: 8
    Text { text: qsTr("Jump into a world"); color: Colors.brass; font.pixelSize: Typography.body; font.weight: Font.DemiBold }
    Repeater {
        model: worlds.entries
        delegate: ItemDelegate {
            id: entry
            required property var modelData
            required property int index
            objectName: "homeQuickWorld_" + index
            Layout.fillWidth: true
            implicitHeight: 46
            Accessible.name: qsTr("Play %1").arg(modelData.name)
            onClicked: {
                if (worlds.controller.instances.launchWorld(worlds.instanceId, modelData.name))
                    worlds.controller.followLaunch(worlds.instanceId);
            }
            background: Rectangle { radius: 12; color: entry.hovered ? Colors.surfaceHi : Colors.mantle; border.color: entry.visualFocus ? Colors.accent : "transparent" }
            contentItem: RowLayout {
                LineIcon { name: "world"; implicitWidth: 18; implicitHeight: 18; tint: Colors.accent }
                Text { Layout.fillWidth: true; text: entry.modelData.name; color: Colors.text; font.pixelSize: Typography.body; elide: Text.ElideRight }
                Text { text: "▶"; color: Colors.accent; font.pixelSize: Typography.body }
            }
        }
    }
    Text { Layout.fillWidth: true; visible: !worlds.entries.length; text: qsTr("Saved worlds appear here after your first adventure."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
}
