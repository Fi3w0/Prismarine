import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: bar
    required property var controller
    property string world: ""
    required property string targetId
    required property string contentType
    readonly property var selection: controller.downloads.items(targetId, contentType)
    Layout.fillWidth: true
    implicitHeight: 64
    radius: 12
    color: Colors.surfaceHi
    border.color: selection.length ? Qt.darker(Colors.accent, 1.9) : Colors.border
    RowLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 12
        Text { text: bar.selection.length + " selected"; color: Colors.text; font.pixelSize: 13; font.weight: Font.DemiBold }
        ListView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            orientation: ListView.Horizontal
            spacing: 8
            clip: true
            model: bar.selection
            delegate: ActionButton {
                required property var modelData
                implicitWidth: Math.min(180, contentItem.implicitWidth + 24)
                text: modelData.project.title + "  ×"
                implicitHeight: 38
                onClicked: bar.controller.downloads.remove(bar.targetId, bar.contentType, modelData.project.project_id)
                ToolTip.visible: hovered
                ToolTip.text: "Remove " + modelData.project.title
            }
        }
        ActionButton { text: "Clear"; compact: true; implicitWidth: 76; enabled: bar.selection.length > 0; onClicked: bar.controller.downloads.clear(bar.targetId, bar.contentType) }
        ActionButton {
            objectName: "reviewSelectionButton"
            text: "Review & install" + (bar.selection.length ? " (" + bar.selection.length + ")" : "")
            primary: true
            enabled: bar.selection.length > 0 && (bar.contentType !== "datapack" || !!bar.world)
            onClicked: bar.controller.reviewSelection(bar.targetId, bar.contentType, bar.world)
        }
    }
}
