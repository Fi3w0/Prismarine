import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: panel
    required property var controller
    readonly property var contents: controller.details
    readonly property var settings: controller.launchSettings
    readonly property var accounts: [
        {
            name: "Default account",
            id: ""
        }
    ].concat(controller.instances.accounts)
    readonly property var values: settings.instanceId === contents.instanceId ? settings.values : ({})
    property real panelWidth: width
    signal chooseCover
    function save(key, value) {
        settings.load(contents.instanceId);
        let next = Object.assign({}, settings.values);
        next[key] = value;
        if (key === "maxMemory")
            next.memoryOverride = true;
        if (settings.save(next)) {
            controller.details.refresh();
            controller.notify("Instance settings saved");
        }
    }
    Component.onCompleted: settings.load(contents.instanceId)
    Connections {
        target: panel.contents
        function onChanged() {
            if (panel.settings.instanceId !== panel.contents.instanceId)
                panel.settings.load(panel.contents.instanceId);
        }
    }
    // Grows with its rows instead of clipping the last buttons.
    Layout.preferredHeight: rows.implicitHeight + 36
    radius: 12
    color: Colors.surface
    border.color: Colors.border
    ColumnLayout {
        id: rows
        anchors {
            fill: parent
            margins: 18
        }
        spacing: 12
        Text {
            text: "Quick settings"
            font.family: Colors.displayFont
            font.pixelSize: 20
            font.letterSpacing: 2
            color: Colors.bone
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Max memory"
                color: Colors.text
                font.pixelSize: 13
            }
            Item {
                Layout.fillWidth: true
            }
            Text {
                text: (memorySlider.value / 1024).toFixed(memorySlider.value % 1024 ? 1 : 0) + " GiB"
                color: Colors.accent
                font.pixelSize: 13
                font.weight: Font.Bold
            }
        }
        Slider {
            id: memorySlider
            objectName: "quickMemorySlider"
            Layout.fillWidth: true
            from: Math.max(512, panel.values.minMemory || 512)
            to: Math.max(32768, panel.values.maxMemory || 4096)
            stepSize: 512
            value: panel.values.maxMemory || 4096
            onMoved: if (!pressed)
                panel.save("maxMemory", value)
            onPressedChanged: if (!pressed)
                panel.save("maxMemory", value)
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "Play as"
                color: Colors.text
                font.pixelSize: 13
            }
            Item {
                Layout.fillWidth: true
            }
            SelectBox {
                Layout.preferredWidth: 170
                model: panel.accounts
                textRole: "name"
                currentIndex: Math.max(0, panel.accounts.findIndex(a => a.id === (panel.values.accountId || "")))
                onActivated: panel.save("accountId", model[currentIndex].id)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Text {
                text: "While playing"
                color: Colors.text
                font.pixelSize: 13
            }
            Item {
                Layout.fillWidth: true
            }
            SelectBox {
                objectName: "instanceWhilePlaying"
                readonly property var keys: ["", "keep", "minimize", "hide"]
                readonly property var labels: ({ keep: "keep open", minimize: "minimize", hide: "hide" })
                Layout.preferredWidth: 170
                model: ["Default (" + labels[controller.preferences.whilePlaying] + ")", "Keep Prismarine open", "Minimize Prismarine", "Hide until it closes"]
                currentIndex: Math.max(0, keys.indexOf(controller.preferences.instanceWhilePlaying[contents.instanceId] || ""))
                onActivated: index => controller.preferences.setInstanceWhilePlaying(contents.instanceId, keys[index])
            }
        }
        ActionButton {
            Layout.fillWidth: true
            text: "All instance settings…"
            onClicked: controller.editSettings(contents.instanceId)
        }
        ActionButton {
            Layout.fillWidth: true
            text: "Card & banner images…"
            implicitHeight: 32
            onClicked: panel.chooseCover()
        }
    }
}
