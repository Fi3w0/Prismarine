import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

GridLayout {
    required property var controller
    readonly property var library: controller.instances.allInstances

    Layout.fillWidth: true
    columns: width < 780 ? 2 : 4
    rowSpacing: 18
    columnSpacing: 18
    Repeater {
        model: library.slice(1, 5)
        delegate: ColumnLayout {
            id: recent
            required property var modelData
            Layout.fillWidth: true
            spacing: 8
            CoverArt {
                Layout.fillWidth: true
                Layout.preferredHeight: 140
                instanceId: recent.modelData.instanceId
                cover: controller.coverFor(instanceId, "card")
                screenshot: recent.modelData.screenshot
                showScreenshot: controller.screenshotFor(instanceId, "card")
                Text {
                    anchors {
                        left: parent.left
                        right: parent.right
                        bottom: parent.bottom
                        margins: 14
                    }
                    text: recent.modelData.name
                    color: Colors.artText
                    font.family: Colors.displayFont
                    font.pixelSize: 20
                    font.letterSpacing: 1
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                }
                Rectangle {
                    anchors {
                        top: parent.top
                        right: parent.right
                        margins: 10
                    }
                    width: dateLabel.implicitWidth + 14
                    height: 22
                    radius: 6
                    color: Qt.rgba(0, 0, 0, 0.45)
                    Text {
                        id: dateLabel
                        anchors.centerIn: parent
                        text: recent.modelData.lastPlayed
                        color: Colors.artText
                        font.pixelSize: 11
                    }
                }
                TapHandler {
                    onTapped: controller.openInstance(recent.modelData.instanceId)
                }
                HoverHandler {
                    cursorShape: Qt.PointingHandCursor
                }
            }
            Text {
                Layout.fillWidth: true
                text: recent.modelData.loader + " " + recent.modelData.version + " · " + recent.modelData.mods + " mods · " + recent.modelData.played
                font.pixelSize: 12
                color: Colors.subtext
                elide: Text.ElideRight
            }
        }
    }
}
