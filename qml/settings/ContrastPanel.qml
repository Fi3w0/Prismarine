import QtQuick
import QtQuick.Layouts

Rectangle {
    id: panel
    required property var previewColors
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 40
    radius: 20
    color: Colors.surface
    border.color: Colors.border
    function luminance(c) {
        function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
        return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
    }
    function ratio(a, b) { const x = luminance(a), y = luminance(b); return (Math.max(x, y) + 0.05) / (Math.min(x, y) + 0.05); }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 18
        Text { text: qsTr("Contrast"); color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: Typography.body; font.letterSpacing: 2 }
        Repeater {
            model: [
                {label: qsTr("Text on window"), ink: panel.previewColors.text, bg: panel.previewColors.base},
                {label: qsTr("Text on cards"), ink: panel.previewColors.text, bg: panel.previewColors.surface},
                {label: qsTr("Hints on fields"), ink: panel.previewColors.subtext, bg: panel.previewColors.surfaceHi},
                {label: qsTr("Text on accent buttons"), ink: panel.previewColors.accentInk, bg: panel.previewColors.accent},
                {label: qsTr("Accent on background"), ink: panel.previewColors.accent, bg: panel.previewColors.base},
                {label: qsTr("Field outlines"), ink: panel.previewColors.outline, bg: panel.previewColors.surfaceHi, minimum: 3}
            ]
            delegate: RowLayout {
                required property var modelData
                readonly property real contrast: panel.ratio(modelData.ink, modelData.bg)
                Layout.fillWidth: true
                spacing: 10
                Rectangle {
                    implicitWidth: 32; implicitHeight: 28; radius: 6; color: modelData.bg
                    Text { anchors.centerIn: parent; text: "Aa"; color: modelData.ink; font.pixelSize: Typography.caption; font.weight: Font.Bold }
                }
                Text { Layout.fillWidth: true; text: modelData.label; color: Colors.text; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
                Text { text: contrast.toFixed(1) + ":1"; color: Colors.subtext; font.pixelSize: Typography.bodySmall }
                Text { Layout.preferredWidth: 32; text: modelData.minimum === 3 ? (contrast >= 3 ? qsTr("Pass") : qsTr("Low")) : contrast >= 7 ? "AAA" : contrast >= 4.5 ? "AA" : qsTr("Low"); color: contrast >= (modelData.minimum || 4.5) ? Colors.success : Colors.warning; font.pixelSize: Typography.bodySmall; font.weight: Font.DemiBold }
            }
        }
        Text { Layout.fillWidth: true; text: qsTr("Text: aim for 4.5:1 or higher. Field outlines: 3:1 or higher."); color: Colors.subtext; font.pixelSize: Typography.caption; wrapMode: Text.Wrap }
    }
}
