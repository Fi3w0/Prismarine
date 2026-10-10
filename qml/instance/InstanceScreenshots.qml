import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

GridView {
    id: screenshots
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info
    property var selectedShot: ({})
    anchors {
        fill: parent
        margins: 28
    }
    visible: controller.instanceTab === "screenshots"
    clip: true
    property string query: ""
    model: query ? contents.screenshots.filter(it => it.fileName.toLowerCase().indexOf(query.toLowerCase()) >= 0) : contents.screenshots
    header: Item {
        width: screenshots.width
        height: contents.screenshots.length > 8 ? 56 : 0
        visible: contents.screenshots.length > 8
        InputField {
            objectName: "screenshotSearch"
            width: Math.min(320, parent.width)
            placeholderText: "Search " + contents.screenshots.length + " screenshots by date or name…"
            font.pixelSize: 13
            onTextChanged: screenshots.query = text.trim()
        }
    }
    cellWidth: width / Math.max(2, Math.floor(width / 290))
    cellHeight: 252
    ScrollBar.vertical: ScrollBar {}
    delegate: ColumnLayout {
        id: shot
        required property var modelData
        width: screenshots.cellWidth - 16
        height: screenshots.cellHeight - 16
        spacing: 8
        Image {
            Layout.fillWidth: true
            Layout.fillHeight: true
            source: shot.modelData.url
            sourceSize.width: 600
            fillMode: Image.PreserveAspectCrop
            clip: true
            asynchronous: true
            TapHandler {
                onTapped: {
                    screenshots.selectedShot = shot.modelData;
                    shotPreview.open();
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: modelData.date
            color: Colors.subtext
            font.pixelSize: 12
        }
        ActionButton {
            Layout.fillWidth: true
            text: "Use as cover"
            onClicked: {
                if (controller.preferences.setCover(contents.instanceId, modelData.url))
                    controller.notify("Cover updated");
            }
        }
    }
    Text {
        anchors.centerIn: parent
        visible: !contents.loading && !contents.screenshots.length
        text: "Take a screenshot in Minecraft with F2.\nIt will appear here."
        color: Colors.subtext
        horizontalAlignment: Text.AlignHCenter
        font.pixelSize: 15
    }
    MotionDialog {
        id: shotPreview
        anchors.centerIn: parent
        width: screenshots.width - 64
        height: screenshots.height - 64
        modal: true
        title: screenshots.selectedShot.fileName || "Screenshot"
        standardButtons: Dialog.Close
        background: Rectangle {
            radius: 14
            color: Colors.surface
            border.color: Colors.border
        }
        contentItem: Image {
            source: screenshots.selectedShot.url || ""
            fillMode: Image.PreserveAspectFit
        }
    }
}
