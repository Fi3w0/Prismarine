import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ColumnLayout {
    id: panel
    required property var controller
    Layout.fillWidth: true
    spacing: 24
    ActionButton {
        text: qsTr("Open Classic Prism…")
        onClicked: if (panel.controller.instances.openPrism()) panel.controller.notify(qsTr("Opening Classic Prism…"))
    }
    ColumnLayout {
        Layout.fillWidth: true
        spacing: 6
        Text { text: "Prism Launcher program"; color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold }
        Text {
            Layout.fillWidth: true
            text: "Which Prism Prismarine starts games with. A Prism built with Prismarine's patch shows no “Please wait…” window unless its own launcher window is open. Leave empty to use the one next to Prismarine, or the installed Prism."
            color: Colors.subtext
            font.pixelSize: Typography.bodySmall
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            InputField {
                id: prismProgram
                objectName: "prismProgramField"
                Layout.fillWidth: true
                text: panel.controller.preferences.prismProgram
                placeholderText: "Automatic: " + (panel.controller.instances.prismProgram() || "not found")
                onEditingFinished: panel.controller.preferences.prismProgram = text
            }
            ActionButton { text: "Browse…"; implicitWidth: 110; onClicked: prismPicker.open() }
            TextLink {
                visible: !!panel.controller.preferences.prismProgram
                text: "Automatic"
                pixelSize: Typography.body
                onClicked: { panel.controller.preferences.prismProgram = ""; prismProgram.text = ""; }
            }
        }
        FileDialog {
            id: prismPicker
            title: "Choose the Prism Launcher program"
            onAccepted: panel.controller.preferences.setPrismProgramFromUrl(selectedFile)
        }
    }
    RowLayout {
        Layout.fillWidth: true
        visible: !!panel.controller.desktop && panel.controller.desktop.kdeAvailable
        spacing: 32
        ColumnLayout {
            Layout.fillWidth: true
            Text { text: "Hide Prism's progress window"; color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold }
            Text {
                Layout.fillWidth: true
                text: "Adds a KDE window rule that keeps Prism's “Please wait…” window minimized, so only Prismarine's launch screen shows. It also applies to that window inside Prism itself. Prism's error messages still appear. Turning this off removes the rule."
                color: Colors.subtext
                font.pixelSize: Typography.bodySmall
                wrapMode: Text.Wrap
            }
        }
        ToggleSwitch {
            objectName: "hidePrismProgressToggle"
            checked: !!panel.controller.desktop && panel.controller.desktop.hidePrismProgress
            onToggled: {
                if (panel.controller.desktop.setHidePrismProgress(checked))
                    panel.controller.notify(checked ? "Prism's progress window will stay minimized" : "Prism's progress window shows again");
            }
        }
    }
}
