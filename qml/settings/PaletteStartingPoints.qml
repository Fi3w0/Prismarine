import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

ColumnLayout {
    id: presets
    required property var preferences
    required property var previewColors
    Layout.fillWidth: true
    spacing: 10
    Text { text: qsTr("Palette starting points"); color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold }
    Text { Layout.fillWidth: true; text: qsTr("Start with Prismarine's colours, then make them yours. Nothing changes outside the preview until Apply."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
    Flow {
        id: cards
        Layout.fillWidth: true
        spacing: 10
        Repeater {
            model: [
                {name: qsTr("Deep sea"), key: "default", dark: ["#070f17", "#0d1822", "#142331", "#1a2d3d"], light: ["#e3e9e6", "#eef1ee", "#f8faf8", "#e2ebe8"]},
                {name: qsTr("Midnight"), key: "midnight", dark: ["#080d18", "#0d1424", "#151f34", "#202e46"], light: ["#e2e7f1", "#eef1f8", "#fafbff", "#e0e7f1"]},
                {name: qsTr("Sea glass"), key: "glass", dark: ["#071712", "#0d211c", "#153129", "#1a352d"], light: ["#deeee5", "#eaf5ee", "#f8fff9", "#dceee4"]},
                {name: qsTr("Slate"), key: "slate", dark: ["#101319", "#181d25", "#232b35", "#29333f"], light: ["#e5e8ed", "#eff1f4", "#fafbfd", "#e2e7ec"]}
            ]
            delegate: AbstractButton {
                id: card
                required property var modelData
                readonly property var swatches: presets.previewColors.light ? modelData.light : modelData.dark
                width: (cards.width - (cards.width < 600 ? 10 : 30)) / (cards.width < 600 ? 2 : 4)
                implicitHeight: 76
                objectName: "paletteStart_" + modelData.key
                padding: 10
                Accessible.name: qsTr("Preview %1 palette").arg(modelData.name)
                onClicked: {
                    const values = JSON.parse(JSON.stringify(presets.preferences.paletteOverrides));
                    const theme = presets.previewColors.light ? "light" : "deep";
                    if (modelData.key === "default") delete values[theme];
                    else values[theme] = {rail: swatches[0], mantle: swatches[0], base: swatches[1], surface: swatches[2], surfaceHi: swatches[3], rowAlt: swatches[2], inset: swatches[2], hero: swatches[2]};
                    presets.preferences.paletteOverrides = values;
                }
                background: Rectangle { radius: 12; color: card.hovered ? Colors.surfaceHi : Colors.surface; border.color: card.visualFocus ? Colors.accent : Colors.border }
                contentItem: ColumnLayout {
                    spacing: 8
                    Row {
                        Layout.fillWidth: true
                        Repeater { model: card.swatches; Rectangle { required property string modelData; width: (card.width - 20) / 4; height: 22; color: modelData } }
                    }
                    Text { Layout.fillWidth: true; text: card.modelData.name; color: Colors.text; font.pixelSize: Typography.bodySmall; elide: Text.ElideRight }
                }
            }
        }
    }
}
