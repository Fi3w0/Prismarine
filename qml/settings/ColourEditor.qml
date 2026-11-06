import QtQuick
import QtQuick.Controls.Basic
import QtQuick.Layouts

Rectangle {
    id: editor
    required property var preferences
    property var previewColors: Colors
    property string role: "accent"
    property string roleLabel: qsTr("Accent")
    property string roleHint: qsTr("Buttons, selection and highlights.")
    property var roles: []
    signal roleSelected(string role)
    readonly property bool roleModified: role === "accent" ? preferences.accentColor.toString() !== "#46d1bb" : Object.prototype.hasOwnProperty.call(preferences.paletteOverrides[previewColors.light ? "light" : "deep"] || {}, role)
    readonly property color valueColor: role === "accent" ? preferences.accentColor : previewColors[role]
    onValueColorChanged: syncColour()
    function writeColour(value) {
        if (role === "accent") preferences.accentColor = value;
        else {
            const map = JSON.parse(JSON.stringify(preferences.paletteOverrides));
            const theme = previewColors.light ? "light" : "deep";
            if (!map[theme]) map[theme] = {};
            map[theme][role] = value.toString();
            preferences.paletteOverrides = map;
        }
    }
    function resetColour() {
        if (role === "accent") preferences.accentColor = "#46d1bb";
        else {
            const map = JSON.parse(JSON.stringify(preferences.paletteOverrides));
            const theme = previewColors.light ? "light" : "deep";
            if (map[theme]) { delete map[theme][role]; if (!Object.keys(map[theme]).length) delete map[theme]; }
            preferences.paletteOverrides = map;
        }
    }
    property real hue: 0.47
    property real saturation: 0.67
    property real brightness: 0.82
    implicitHeight: form.implicitHeight + 40
    radius: 20
    color: Colors.surfaceHi
    border.color: Colors.border
    function syncColour() {
        const c = valueColor;
        if (c.hsvSaturation > 0 && c.hsvValue > 0) hue = c.hsvHue;
        saturation = c.hsvSaturation; brightness = c.hsvValue;
        if (hex) hex.text = c.toString();
    }
    function choose(h, s, v) {
        hue = Math.max(0, Math.min(0.99999, h));
        saturation = Math.max(0, Math.min(1, s));
        brightness = Math.max(0, Math.min(1, v));
        writeColour(Qt.hsva(hue, saturation, brightness, 1));
    }
    Component.onCompleted: syncColour()
    ColumnLayout {
        id: form
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 16
        Text { text: qsTr("Colour editor"); color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: Typography.body; font.letterSpacing: 2 }
        RowLayout {
            visible: editor.roles.length > 0
            Layout.fillWidth: true
            SelectBox {
                objectName: "paletteRolePicker"
                Layout.fillWidth: true
                model: editor.roles
                textRole: "label"
                currentIndex: model.findIndex(entry => entry.key === editor.role)
                Accessible.name: qsTr("Colour role to edit")
                onActivated: editor.roleSelected(model[currentIndex].key)
            }
            ActionButton {
                objectName: "resetPaletteColour"
                implicitWidth: 130
                text: qsTr("Reset colour")
                enabled: editor.roleModified
                onClicked: editor.resetColour()
            }
        }
        GridLayout {
            Layout.fillWidth: true
            columns: editor.width < 470 ? 1 : 2
            rowSpacing: 12
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { text: editor.roleLabel; color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold }
                Text { Layout.fillWidth: true; wrapMode: Text.Wrap; text: editor.roleHint; color: Colors.subtext; font.pixelSize: Typography.bodySmall }
            }
            Row {
                spacing: 6
                Repeater {
                    model: ["#46d1bb", "#7aa2ff", "#f0a35e", "#b892f2", "#d8c39a", "#f18ba8"]
                    delegate: AbstractButton {
                        id: preset
                        required property string modelData
                        required property int index
                        objectName: "accentPreset_" + index
                        implicitWidth: 28
                        implicitHeight: 28
                        Accessible.name: qsTr("Accent %1").arg(modelData)
                        onClicked: editor.writeColour(Qt.color(modelData))
                        background: Rectangle {
                            radius: 14
                            color: preset.modelData
                            border.width: editor.valueColor.toString() === preset.modelData || preset.visualFocus ? 2 : 0
                            border.color: Colors.bone
                        }
                    }
                }
            }
        }
        Rectangle {
            id: sv
            objectName: "accentSaturationValue"
            Layout.fillWidth: true
            implicitHeight: Math.max(150, Math.min(220, width * 0.48))
            color: Qt.hsva(editor.hue, 1, 1, 1)
            activeFocusOnTab: true
            // A controller moves past this, and adjusts it only after pressing confirm.
            readonly property bool gamepadAdjustable: true
            readonly property var gamepadValue: [editor.hue, editor.saturation, editor.brightness]
            function gamepadRestore(value) { editor.choose(value[0], value[1], value[2]); }
            Accessible.role: Accessible.Slider
            Accessible.name: qsTr("Accent saturation and brightness")
            Keys.onLeftPressed: editor.choose(editor.hue, editor.saturation - 0.01, editor.brightness)
            Keys.onRightPressed: editor.choose(editor.hue, editor.saturation + 0.01, editor.brightness)
            Keys.onUpPressed: editor.choose(editor.hue, editor.saturation, editor.brightness + 0.01)
            Keys.onDownPressed: editor.choose(editor.hue, editor.saturation, editor.brightness - 0.01)
            Rectangle {
                anchors.fill: parent
                gradient: Gradient { orientation: Gradient.Horizontal; GradientStop { position: 0; color: "white" } GradientStop { position: 1; color: "transparent" } }
            }
            Rectangle {
                anchors.fill: parent
                gradient: Gradient { GradientStop { position: 0; color: "transparent" } GradientStop { position: 1; color: "black" } }
                border.width: sv.activeFocus ? 2 : 1
                border.color: sv.activeFocus ? Colors.bone : Colors.border
            }
            Rectangle {
                x: editor.saturation * (parent.width - 14)
                y: (1 - editor.brightness) * (parent.height - 14)
                width: 14; height: 14; radius: 7
                color: editor.valueColor
                border.width: 2; border.color: "white"
            }
            MouseArea {
                anchors.fill: parent
                preventStealing: true
                function update(x, y) { editor.choose(editor.hue, x / width, 1 - y / height); }
                onPressed: mouse => { sv.forceActiveFocus(); update(mouse.x, mouse.y); }
                onPositionChanged: mouse => { if (pressed) update(mouse.x, mouse.y); }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 2
            Repeater {
                model: [{name: "H", key: "hue", factor: 359, unit: "°"}, {name: "S", key: "saturation", factor: 100, unit: "%"}, {name: "V", key: "brightness", factor: 100, unit: "%"}]
                delegate: RowLayout {
                    id: channel
                    required property var modelData
                    Layout.fillWidth: true
                    Text { text: channel.modelData.name; color: Colors.subtext; font.pixelSize: Typography.bodySmall; Layout.preferredWidth: 16 }
                    Slider {
                        id: slider
                        objectName: "accentChannel_" + channel.modelData.name
                        Layout.fillWidth: true
                        from: 0; to: 1
                        stepSize: 0.01
                        value: editor[channel.modelData.key]
                        Accessible.name: ({H: qsTr("Hue"), S: qsTr("Saturation"), V: qsTr("Brightness")})[channel.modelData.name]
                        onMoved: editor.choose(channel.modelData.key === "hue" ? value : editor.hue, channel.modelData.key === "saturation" ? value : editor.saturation, channel.modelData.key === "brightness" ? value : editor.brightness)
                        background: Rectangle {
                            x: slider.leftPadding; y: (slider.height - height) / 2
                            width: slider.availableWidth; height: 8; radius: 4
                            color: Colors.outline
                            Rectangle {
                                anchors.fill: parent
                                visible: channel.modelData.key === "hue"
                                radius: 4
                                gradient: Gradient {
                                    orientation: Gradient.Horizontal
                                    GradientStop { position: 0; color: "red" }
                                    GradientStop { position: 0.17; color: "yellow" }
                                    GradientStop { position: 0.33; color: "lime" }
                                    GradientStop { position: 0.5; color: "cyan" }
                                    GradientStop { position: 0.67; color: "blue" }
                                    GradientStop { position: 0.83; color: "magenta" }
                                    GradientStop { position: 1; color: "red" }
                                }
                            }
                        }
                        handle: Rectangle {
                            x: slider.leftPadding + slider.visualPosition * (slider.availableWidth - width)
                            y: (slider.height - height) / 2
                            width: 16; height: 16; radius: 8
                            color: Colors.text
                            border.width: slider.visualFocus ? 2 : 1
                            border.color: slider.visualFocus ? Colors.accent : Colors.outline
                        }
                    }
                    Text { Layout.preferredWidth: 42; horizontalAlignment: Text.AlignRight; text: Math.round(editor[channel.modelData.key] * channel.modelData.factor) + channel.modelData.unit; color: Colors.subtext; font.pixelSize: Typography.bodySmall }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Rectangle { implicitWidth: 40; implicitHeight: 40; radius: 9; color: editor.valueColor }
            InputField {
                id: hex
                objectName: "accentHexField"
                Layout.fillWidth: true
                Accessible.name: qsTr("Accent hex colour")
                validator: RegularExpressionValidator { regularExpression: /^#[0-9a-fA-F]{6}$/ }
                onEditingFinished: { if (acceptableInput) editor.writeColour(Qt.color(text)); else editor.syncColour(); }
            }
            Text { visible: editor.width > 500; text: "RGB " + [editor.valueColor.r, editor.valueColor.g, editor.valueColor.b].map(c => Math.round(c * 255)).join(" / "); color: Colors.subtext; font.pixelSize: Typography.caption }
        }
        Text { Layout.fillWidth: true; text: qsTr("Pick a preset, drag, or enter a hex colour. Apply saves your palette."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
    }
}
