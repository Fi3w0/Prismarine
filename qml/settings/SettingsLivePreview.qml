import QtQuick
import QtQuick.Layouts

Rectangle {
    id: preview
    required property var previewColors
    required property var preferences
    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 40
    radius: 20
    color: Colors.surface
    border.color: Colors.border
    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 16
        Text { text: qsTr("Live preview"); color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: Typography.body; font.letterSpacing: 2 }
        Rectangle {
            objectName: "appearanceLivePreview"
            Layout.fillWidth: true
            implicitHeight: 218
            radius: 14
            color: preview.previewColors.base
            border.color: preview.previewColors.border
            RowLayout {
                anchors { fill: parent; margins: 14 }
                spacing: 18
                Rectangle {
                    Layout.preferredWidth: 34
                    Layout.fillHeight: true
                    radius: preview.previewColors.controlRadius
                    color: preview.previewColors.rail
                    Column {
                        anchors { horizontalCenter: parent.horizontalCenter; top: parent.top; topMargin: 8 }
                        spacing: 8
                        Repeater {
                            model: 3
                            Rectangle { required property int index; width: 18; height: 18; radius: preview.previewColors.controlRadius / 2; color: index === 0 ? preview.previewColors.accent : preview.previewColors.surfaceHi }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 12
                    Rectangle {
                        Layout.fillWidth: true
                        implicitHeight: 40
                        radius: preview.previewColors.controlRadius
                        color: preview.previewColors.hero
                        border.color: preview.previewColors.heroLine
                        Text { anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 8 } text: qsTr("Coastal survival"); color: preview.previewColors.bone; font.family: Colors.displayFont; font.pixelSize: Typography.sectionTitle; elide: Text.ElideRight }
                    }
                    Row {
                        visible: preview.preferences.showCoverBadges
                        spacing: 8
                        Repeater {
                            model: ["Fabric", "1.21.1"]
                            Rectangle {
                                required property string modelData
                                implicitWidth: badge.implicitWidth + 16; implicitHeight: 24; radius: 12
                                color: preview.previewColors.surfaceHi
                                Text { id: badge; anchors.centerIn: parent; text: parent.modelData; color: preview.previewColors.accent; font.pixelSize: Typography.caption }
                            }
                        }
                    }
                    Text { text: qsTr("Your worlds and adventures"); color: preview.previewColors.subtext; font.pixelSize: Typography.caption }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 12
                        Rectangle {
                            implicitWidth: 70; implicitHeight: 36; radius: preview.previewColors.controlRadius
                            color: preview.previewColors.accent
                            Text { anchors.centerIn: parent; text: qsTr("Play"); color: preview.previewColors.accentInk; font.pixelSize: Typography.body; font.weight: Font.DemiBold }
                        }
                        Rectangle {
                            implicitWidth: 38; implicitHeight: 22; radius: 11
                            color: preview.previewColors.accent
                            Rectangle { x: 19; y: 3; width: 16; height: 16; radius: 8; color: preview.previewColors.accentInk }
                        }
                        Rectangle {
                            Layout.fillWidth: true; implicitHeight: 36; radius: preview.previewColors.controlRadius
                            color: preview.previewColors.surfaceHi
                            border.color: preview.previewColors.accent
                            Text { anchors.centerIn: parent; text: qsTr("Focus ring"); color: preview.previewColors.text; font.pixelSize: Typography.caption }
                        }
                    }
                    Rectangle {
                        Layout.fillWidth: true; implicitHeight: 5; radius: 3; color: preview.previewColors.surfaceHi
                        Rectangle { width: parent.width * 0.58; height: 5; radius: 3; color: preview.previewColors.accent }
                    }
                }
            }
        }
    }
}
