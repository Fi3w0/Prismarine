import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    required property var controller
    property real preferredPanelWidth: 400
    property var selectedProject: ({})
    property string targetId: ""
    property string contentType: "mod"
    signal projectSelected(var project)

    Layout.preferredWidth: preferredPanelWidth
    Layout.fillHeight: true
    radius: 14
    color: Colors.surface
    border.color: Colors.border
    ListView {
        id: results
        anchors {
            fill: parent
            margins: 10
        }
        model: controller.catalog.results
        clip: true
        spacing: 6
        ScrollBar.vertical: ScrollBar {}
        delegate: ItemDelegate {
            id: result
            required property var modelData
            objectName: "browseResult_" + modelData.project_id
            width: results.width
            height: 64
            onClicked: projectSelected(modelData)
            background: Rectangle {
                radius: 8
                color: result.hovered || selectedProject.project_id === result.modelData.project_id ? Colors.surfaceHi : "transparent"
            }
            contentItem: RowLayout {
                spacing: 12
                Image {
                    Layout.preferredWidth: 42
                    Layout.preferredHeight: 42
                    source: result.modelData.icon_url || ""
                    fillMode: Image.PreserveAspectFit
                    asynchronous: true
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 5
                    Text {
                        Layout.fillWidth: true
                        text: result.modelData.title
                        color: Colors.text
                        font.pixelSize: 15
                        font.weight: Font.DemiBold
                        elide: Text.ElideRight
                    }
                    Text {
                        Layout.fillWidth: true
                        text: result.modelData.description
                        color: Colors.subtext
                        font.pixelSize: 12
                        elide: Text.ElideRight
                    }

                }
                Text { text: "✓"; visible: controller.downloads.contains(targetId, contentType, result.modelData.project_id); color: Colors.accent; font.pixelSize: 18 }
            }
        }
        BusyIndicator {
            anchors.centerIn: parent
            running: controller.catalog.loading
            visible: running
        }
        Text {
            anchors.centerIn: parent
            width: parent.width - 24
            visible: !controller.catalog.loading && !controller.catalog.results.length
            text: controller.catalog.error || "No matching projects. Try another search."
            color: Colors.subtext
            font.pixelSize: 14
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
        }
    }
}
