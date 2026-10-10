import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: settings
    required property var controller
    property string section: controller.settingsSection || "Interface"
    onSectionChanged: {
        if (section === "Java & game") controller.launchSettings.load("");
        if (section === "Network" && controller.network) controller.network.load();
        if (section === "Storage" && controller.storage && !controller.storage.loading && !controller.storage.instances.length) controller.storage.scan();
    }
    Component.onCompleted: if (section === "Storage" && controller.storage) controller.storage.scan()
    RowLayout {
        anchors {
            fill: parent
            margins: 32
        }
        spacing: 0
        SettingsSidebar {
            controller: settings.controller
            section: settings.section
            onSectionSelected: nextSection => settings.section = nextSection
        }
        ScrollView {
            id: scroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: scroll.availableWidth - 56
                x: 28
                spacing: 24
                Text {
                    text: settings.section
                    color: Colors.bone
                    font.family: Colors.displayFont
                    font.pixelSize: 30
                    font.letterSpacing: 2
                }
                AppearancePreview {
                    controller: settings.controller
                    section: settings.section
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: settings.section === "Interface" || settings.section === "Library & covers"
                    spacing: 32
                    AccentPicker {
                        Layout.preferredWidth: 1
                        controller: settings.controller
                        section: settings.section
                    }
                    ThemePicker {
                        Layout.preferredWidth: 1
                        Layout.alignment: Qt.AlignTop
                        controller: settings.controller
                        section: settings.section
                    }
                }
                LibraryPreferences {
                    controller: settings.controller
                    section: settings.section
                }
                AppearanceSwitches {
                    controller: settings.controller
                    section: settings.section
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: settings.section === "Interface"
                    spacing: 32
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { text: "While a game is running"; color: Colors.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "What Prismarine's window does once the game window opens. Instances can override this in their overview."
                            color: Colors.subtext
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                    }
                    SelectBox {
                        objectName: "whilePlayingSetting"
                        readonly property var keys: ["keep", "minimize", "hide"]
                        Layout.preferredWidth: 260
                        model: ["Keep Prismarine open", "Minimize Prismarine", "Hide until the game closes"]
                        currentIndex: Math.max(0, keys.indexOf(settings.controller.preferences.whilePlaying))
                        onActivated: index => settings.controller.preferences.whilePlaying = keys[index]
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: settings.section === "Interface"
                    spacing: 32
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { text: "Let Prism open its console window"; color: Colors.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Off: Prism never opens its console on its own, not even after a crash. Now playing has the log and crash help, and you can still open the console from Prism yourself. Changes Prism's “Show console” settings."
                            color: Colors.subtext
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                    }
                    ToggleSwitch {
                        objectName: "prismConsoleToggle"
                        checked: settings.controller.preferences.prismConsole
                        onToggled: settings.controller.preferences.prismConsole = checked
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    visible: settings.section === "Interface"
                    spacing: 6
                    Text { text: "Prism Launcher program"; color: Colors.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                    Text {
                        Layout.fillWidth: true
                        text: "Which Prism Prismarine starts games with. A Prism built with Prismarine's patch shows no “Please wait…” window unless its own launcher window is open. Leave empty to use the one next to Prismarine, or the installed Prism."
                        color: Colors.subtext
                        font.pixelSize: 12
                        wrapMode: Text.Wrap
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 10
                        InputField {
                            id: prismProgram
                            objectName: "prismProgramField"
                            Layout.fillWidth: true
                            text: settings.controller.preferences.prismProgram
                            placeholderText: "Automatic: " + (settings.controller.instances.prismProgram() || "not found")
                            onEditingFinished: settings.controller.preferences.prismProgram = text
                        }
                        ActionButton { text: "Browse…"; implicitWidth: 110; onClicked: prismPicker.open() }
                        TextLink {
                            visible: !!settings.controller.preferences.prismProgram
                            text: "Automatic"
                            pixelSize: 13
                            onClicked: { settings.controller.preferences.prismProgram = ""; prismProgram.text = ""; }
                        }
                    }
                    FileDialog {
                        id: prismPicker
                        title: "Choose the Prism Launcher program"
                        onAccepted: settings.controller.preferences.setPrismProgramFromUrl(selectedFile)
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    visible: settings.section === "Interface" && !!settings.controller.desktop && settings.controller.desktop.kdeAvailable
                    spacing: 32
                    ColumnLayout {
                        Layout.fillWidth: true
                        Text { text: "Hide Prism's progress window"; color: Colors.text; font.pixelSize: 14; font.weight: Font.DemiBold }
                        Text {
                            Layout.fillWidth: true
                            text: "Adds a KDE window rule that keeps Prism's “Please wait…” window minimized, so only Prismarine's launch screen shows. It also applies to that window inside Prism itself. Prism's error messages still appear. Turning this off removes the rule."
                            color: Colors.subtext
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                    }
                    ToggleSwitch {
                        objectName: "hidePrismProgressToggle"
                        checked: !!settings.controller.desktop && settings.controller.desktop.hidePrismProgress
                        onToggled: {
                            if (settings.controller.desktop.setHidePrismProgress(checked))
                                settings.controller.notify(checked ? "Prism's progress window will stay minimized" : "Prism's progress window shows again");
                        }
                    }
                }
                LaunchSettingsForm {
                    Layout.fillWidth: true
                    visible: settings.section === "Java & game"
                    javaManager: settings.controller.javaManager
                    service: settings.controller.launchSettings
                    onSaved: settings.controller.notify("Launcher settings saved")
                }
                NetworkSettingsForm {
                    Layout.fillWidth: true
                    visible: settings.section === "Network"
                    controller: settings.controller
                }
                ExperimentalPanel {
                    Layout.fillWidth: true
                    visible: settings.section === "Experimental"
                    controller: settings.controller
                }
                StoragePanel {
                    Layout.fillWidth: true
                    visible: settings.section === "Storage"
                    controller: settings.controller
                }
                AboutPanel {
                    controller: settings.controller
                    section: settings.section
                }
                Item {
                    Layout.preferredHeight: 32
                }
            }
        }
    }
}
