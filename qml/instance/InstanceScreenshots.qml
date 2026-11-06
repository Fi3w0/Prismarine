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
            font.pixelSize: Typography.body
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
        AbstractButton {
            id: shotButton
            Layout.fillWidth: true
            Layout.fillHeight: true
            implicitWidth: 100
            implicitHeight: 100
            padding: 0
            Accessible.name: qsTr("View screenshot from %1").arg(shot.modelData.date)
            onClicked: {
                screenshots.selectedShot = shot.modelData;
                shotPreview.open();
            }
            background: Item {}
            contentItem: Image {
                source: shot.modelData.url
                sourceSize.width: 600
                fillMode: Image.PreserveAspectCrop
                clip: true
                asynchronous: true
            }
            Rectangle {
                anchors.fill: parent
                color: "transparent"
                border.width: 2
                border.color: Colors.accent
                visible: shotButton.visualFocus
            }
        }
        Text {
            Layout.fillWidth: true
            text: modelData.date
            color: Colors.subtext
            font.pixelSize: Typography.bodySmall
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
        font.pixelSize: Typography.bodyLarge
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
