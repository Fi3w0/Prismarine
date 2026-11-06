import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: panel
    required property var controller
    readonly property var feed: controller.news
    readonly property var items: feed ? feed.items : []
    Layout.fillWidth: true
    Layout.fillHeight: true
    implicitHeight: body.implicitHeight + 40
    color: Colors.surface
    radius: 20
    border.color: Colors.border
    Component.onCompleted: if (feed) feed.load()
    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 16
        Text { text: qsTr("News"); color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: Typography.sectionTitle }
        Repeater {
            model: panel.items.slice(0, 3)
            delegate: ItemDelegate {
                id: post
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 48
                hoverEnabled: true
                Accessible.name: modelData.title
                onClicked: Qt.openUrlExternally(modelData.url)
                background: Rectangle { radius: 8; color: post.hovered ? Colors.surfaceHi : "transparent"; border.color: post.visualFocus ? Colors.accent : "transparent" }
                contentItem: RowLayout {
                    spacing: 16
                    Text { Layout.fillWidth: true; text: post.modelData.title; color: Colors.text; font.pixelSize: Typography.body; font.weight: Font.DemiBold; elide: Text.ElideRight }
                    Text { text: post.modelData.date || ""; color: Colors.subtext; font.pixelSize: Typography.bodySmall }
                }
            }
        }
        Text { Layout.fillWidth: true; visible: !panel.items.length; text: !panel.feed ? qsTr("News is off in this session.") : panel.feed.loading ? qsTr("Loading Prism news…") : panel.feed.error || qsTr("No news right now."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
        ActionButton { visible: !!panel.feed && !panel.items.length && !panel.feed.loading; text: qsTr("Try again"); onClicked: panel.feed.load() }
    }
}
