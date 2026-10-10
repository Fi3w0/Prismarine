import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ItemDelegate {
    id: modRow
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info
    property bool selected: false
    // A newer Modrinth version of this file, if one was found.
    property var availableUpdate: null
    signal inspectRequested(var mod)
    signal selectToggled(bool on)
    required property int index
    required property var modelData
    width: ListView.view ? ListView.view.width : implicitWidth
    height: 52
    onClicked: inspectRequested(modelData)
    background: Rectangle {
        radius: 0
        color: modRow.selected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.08) : modRow.hovered ? Colors.surfaceHi : index % 2 ? Colors.rowAlt : Colors.surface
    }
    contentItem: RowLayout {
        spacing: 16
        opacity: modRow.modelData.enabled ? 1 : 0.6
        TickBox {
            checked: modRow.selected
            Accessible.name: "Select " + modRow.modelData.name
            onClicked: modRow.selectToggled(checked)
        }
        ContentIcon {
            size: 34
            source: modRow.modelData.icon || ""
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            Text {
                Layout.fillWidth: true
                text: modRow.modelData.name
                color: modRow.modelData.enabled ? Colors.text : Colors.subtext
                font.pixelSize: 14
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                text: modRow.modelData.fileName
                color: Colors.subtext
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
        Text {
            Layout.preferredWidth: 160
            text: modRow.availableUpdate ? modRow.modelData.version + " → " + modRow.availableUpdate.version : modRow.modelData.version
            color: modRow.availableUpdate ? Colors.accent : Colors.text
            font.pixelSize: 12
            elide: Text.ElideRight
            ToolTip.visible: modRow.availableUpdate && versionHover.hovered
            ToolTip.text: modRow.availableUpdate ? "Update available: " + modRow.availableUpdate.newFileName : ""
            HoverHandler { id: versionHover }
        }
        Text {
            Layout.preferredWidth: 100
            text: modRow.modelData.side
            color: Colors.subtext
            font.pixelSize: 12
        }
        ToggleSwitch {
            Layout.preferredWidth: 66
            checked: modRow.modelData.enabled
            enabled: !contents.loading
            Accessible.name: "Enable " + modRow.modelData.name
            onToggled: if (!contents.setModEnabled(modRow.modelData.fileName, checked))
                checked = modRow.modelData.enabled
        }
    }
}
