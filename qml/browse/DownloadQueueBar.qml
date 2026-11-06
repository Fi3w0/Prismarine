import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: bar
    required property var controller
    property string world: ""
    property string targetName: ""
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
        Text {
            Layout.fillWidth: bar.width < 720
            Layout.maximumWidth: bar.width < 720 ? 240 : 220
            text: qsTr("%1 selected").arg(bar.selection.length) + (bar.targetName ? " · " + bar.targetName : "")
            color: Colors.text
            font.pixelSize: Typography.body
            font.weight: Font.DemiBold
            elide: Text.ElideRight
        }
        ListView {
            visible: bar.width >= 720
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
