import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Latest posts from Prism Launcher's news feed; falls back to quick actions when offline.
Rectangle {
    id: panel
    required property var controller
    readonly property var feed: controller.news
    readonly property var items: feed ? feed.items : []

    Layout.fillWidth: true
    Layout.preferredHeight: 300
    color: Colors.surface
    radius: 16
    border.color: Colors.border
    Component.onCompleted: if (feed) feed.load()
    ColumnLayout {
        anchors {
            fill: parent
            margins: 20
        }
        spacing: 8
        Text {
            text: "News"
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: 20
            font.letterSpacing: 2
            Layout.bottomMargin: 4
        }
        Repeater {
            model: panel.items.slice(0, 3)
            delegate: ItemDelegate {
                id: post
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 64
                padding: 10
                hoverEnabled: true
                Accessible.name: modelData.title
                onClicked: Qt.openUrlExternally(modelData.url)
                background: Rectangle {
                    radius: 8
                    color: post.hovered ? Colors.surfaceHi : Colors.mantle
                    border.color: post.visualFocus ? Colors.accent : "transparent"
                }
                contentItem: ColumnLayout {
                    spacing: 2
                    Text {
                        text: "PRISM LAUNCHER" + (post.modelData.date ? "  ·  " + post.modelData.date.toUpperCase() : "")
                        color: Colors.brass
                        font.pixelSize: 9
                        font.letterSpacing: 1
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: post.modelData.title
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: post.modelData.summary || ""
                        color: Colors.subtext
                        font.pixelSize: 11
                        elide: Text.ElideRight
                    }
                }
                HoverHandler { cursorShape: Qt.PointingHandCursor }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: !panel.items.length
            text: !panel.feed ? "News is off in this session." : panel.feed.loading ? "Loading Prism news…" : panel.feed.error || ""
            color: Colors.subtext
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Item {
            Layout.fillHeight: true
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            ActionButton {
                Layout.fillWidth: true
                implicitWidth: 0
                implicitHeight: 34
                font.pixelSize: 12
                text: "+ New instance"
                onClicked: panel.controller.createInstance()
            }
            ActionButton {
                Layout.fillWidth: true
                implicitWidth: 0
                implicitHeight: 34
                font.pixelSize: 12
                text: "Browse content →"
                onClicked: panel.controller.navigate("browse")
            }
        }
    }
}
