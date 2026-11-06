import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

GridLayout {
    id: recentGrid
    required property var controller
    property var library: controller.instances.allInstances

    Layout.fillWidth: true
    columns: width < 780 ? 2 : 5
    rowSpacing: 18
    columnSpacing: 18
    Repeater {
        model: library.slice(1, 5)
        delegate: AbstractButton {
            id: recent
            objectName: "homeRecentTile"
            required property var modelData
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            padding: 0
            hoverEnabled: true
            Accessible.name: qsTr("Open %1").arg(modelData.name)
            HoverHandler { cursorShape: Qt.PointingHandCursor }
            onClicked: controller.openInstance(modelData.instanceId)
            background: Rectangle {
                anchors.fill: parent
                anchors.margins: -4
                radius: 16
                color: "transparent"
                border.color: recent.visualFocus ? Colors.accent : "transparent"
            }
            contentItem: ColumnLayout {
                spacing: 8
                CoverArt {
                    Layout.fillWidth: true
                    Layout.preferredHeight: width * 0.78
                    instanceId: recent.modelData.instanceId
                    cover: controller.coverFor(instanceId, "card")
                    screenshot: recent.modelData.screenshot
                    showScreenshot: controller.screenshotFor(instanceId, "card")
                    Text {
                        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
                        text: recent.modelData.name
                        color: Colors.artText
                        font.family: Colors.displayFont
                        font.pixelSize: Typography.sectionTitle
                        wrapMode: Text.Wrap
                        maximumLineCount: 2
                        elide: Text.ElideRight
                    }
                }
                Text {
                    Layout.fillWidth: true
                    text: recent.modelData.loader + " " + recent.modelData.version
                    textFormat: Text.PlainText
                    color: Colors.text
                    font.pixelSize: Typography.body
                    elide: Text.ElideRight
                }
                Text {
                    Layout.fillWidth: true
                    text: recent.modelData.mods + " mods · " + recent.modelData.played
                    font.pixelSize: Typography.bodySmall
                    color: Colors.subtext
                    elide: Text.ElideRight
                }
            }
        }
    }
    AbstractButton {
        id: create
        objectName: "homeNewInstance"
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.alignment: Qt.AlignTop
        padding: 0
        Accessible.name: qsTr("New instance")
        onClicked: controller.createInstance()
        background: Item {}
        contentItem: ColumnLayout {
            spacing: 8
            Rectangle {
                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.78
                radius: 16
                color: create.hovered ? Colors.surfaceHi : Colors.surface
                border.color: create.visualFocus ? Colors.accent : Colors.outline
                Column {
                    anchors.centerIn: parent
                    spacing: 12
                    LineIcon { anchors.horizontalCenter: parent.horizontalCenter; name: "plus"; width: 28; height: 28; tint: Colors.subtext }
                    Text { text: qsTr("New instance"); color: Colors.text; font.pixelSize: Typography.body; font.weight: Font.DemiBold }
                }
            }
            Text { Layout.fillWidth: true; text: qsTr("Blank, modpack or import"); color: Colors.text; font.pixelSize: Typography.body; wrapMode: Text.Wrap }
            Text { Layout.fillWidth: true; text: qsTr("Game files download on first play"); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
        }
    }
    Repeater {
        model: Math.max(0, recentGrid.columns - Math.min(4, recentGrid.library.slice(1).length) - 1)
        Item { Layout.fillWidth: true; Layout.preferredWidth: 1 }
    }
}
