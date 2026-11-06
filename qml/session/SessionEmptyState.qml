import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Nothing launched yet: quick play from the most recent instances.
ColumnLayout {
    required property var page
    spacing: 16
    Text { Layout.alignment: Qt.AlignHCenter; text: "Nothing running"; color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: Typography.pageTitle }
    Text {
        Layout.fillWidth: true
        horizontalAlignment: Text.AlignHCenter
        text: "Start an instance and its live log, memory use and launch steps appear here."
        color: Colors.subtext
        font.pixelSize: Typography.control
        wrapMode: Text.Wrap
    }
    Repeater {
        model: page.controller.instances.allInstances.slice().sort((a, b) => b.lastLaunchMs - a.lastLaunchMs).slice(0, 4)
        delegate: Rectangle {
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: 60
            radius: 12
            color: Colors.surface
            border.color: Colors.border
            RowLayout {
                anchors { fill: parent; margins: 10; leftMargin: 14 }
                spacing: 12
                InstanceIcon { size: 36; icon: modelData.icon || ""; name: modelData.name; loader: modelData.loader }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Text { Layout.fillWidth: true; text: modelData.name; color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { text: modelData.loader + " · " + modelData.version + " · " + modelData.lastPlayed; color: Colors.subtext; font.pixelSize: Typography.bodySmall }
                }
                ActionButton { text: "▶ Play"; primary: true; implicitWidth: 96; implicitHeight: 36; onClicked: page.controller.play(modelData.instanceId, modelData.name) }
            }
        }
    }
}
