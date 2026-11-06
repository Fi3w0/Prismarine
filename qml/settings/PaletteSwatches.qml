import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: swatches
    required property var roles
    required property var preferences
    required property var previewColors
    required property string selectedRole
    signal roleSelected(string role)
    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 36
    radius: 20
    color: Colors.surface
    border.color: Colors.border
    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
        spacing: 14
        Text { text: qsTr("Palette"); color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: Typography.body; font.letterSpacing: 2 }
        Text { Layout.fillWidth: true; text: swatches.previewColors.light ? qsTr("Editing the Light palette") : qsTr("Editing the Deep sea palette"); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: swatches.roles
                delegate: AbstractButton {
                    id: role
                    required property var modelData
                    readonly property color value: modelData.key === "accent" ? swatches.preferences.accentColor : swatches.previewColors[modelData.key]
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 54
                    padding: 8
                    objectName: "paletteRole_" + modelData.key
                    Accessible.name: qsTr("Edit %1 colour").arg(modelData.label)
                    onClicked: swatches.roleSelected(modelData.key)
                    background: Rectangle { radius: 10; color: role.hovered ? Colors.surfaceHi : Colors.mantle; border.color: swatches.selectedRole === role.modelData.key || role.visualFocus ? Colors.accent : Colors.border }
                    contentItem: RowLayout {
                        spacing: 8
                        Rectangle { implicitWidth: 24; implicitHeight: 30; radius: 5; color: role.value; border.color: Colors.outline }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { Layout.fillWidth: true; text: role.modelData.label; color: Colors.text; font.pixelSize: Typography.bodySmall; elide: Text.ElideRight }
                            Text { Layout.fillWidth: true; text: role.value.toString(); color: Colors.subtext; font.pixelSize: Typography.caption; elide: Text.ElideRight }
                        }
                    }
                }
            }
        }
    }
}
