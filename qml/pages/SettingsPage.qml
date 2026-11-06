import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: settings
    objectName: "settingsPage"
    required property var controller
    readonly property bool compactLayout: width < 1050 || height < 650
    SettingsDraft { id: appearanceDraft; objectName: "appearanceDraft"; preferences: settings.controller.preferences }
    QtObject {
        id: appearanceController
        property var preferences: appearanceDraft
        property var instances: settings.controller.instances
        property var appInfo: settings.controller.appInfo
        property bool prismShortcuts: settings.controller.prismShortcuts !== false
        property var gamepad: settings.controller.gamepad
        function notify(message) { settings.controller.notify(message); }
    }
    readonly property bool appearanceSection: section === "Interface" || section === "Library & covers"
    property string section: controller.settingsSection || "Interface"
    onSectionChanged: {
        if (scroll && scroll.contentItem) scroll.contentItem.contentY = 0;
        if (section === "Java & game") controller.launchSettings.load("");
        if (section === "Network" && controller.network) controller.network.load();
        if (section === "Storage" && controller.storage && !controller.storage.loading && !controller.storage.instances.length) controller.storage.scan();
    }
    function chooseSection(name) {
        if (name === "Accounts") controller.navigate("accounts");
        else section = name;
    }
    Component.onCompleted: if (section === "Storage" && controller.storage) controller.storage.scan()
    ColumnLayout {
        anchors { fill: parent; margins: settings.compactLayout ? 20 : 28 }
        spacing: 16
        RowLayout {
            visible: settings.compactLayout
            Layout.fillWidth: true
            Layout.maximumWidth: settingsBody.width
            Layout.alignment: Qt.AlignHCenter
            InputField {
                id: compactSearch
                objectName: visible ? "settingsSearch" : ""
                Layout.fillWidth: true
                placeholderText: qsTr("Search settings…")
                Accessible.name: qsTr("Search settings")
                readonly property var matches: {
                    const tokens = text.trim().toLowerCase().split(/\s+/).filter(it => it.length);
                    return settings.controller.settingsSections.filter(it => tokens.every(token => (it.name + " " + it.words).toLowerCase().indexOf(token) >= 0));
                }
                onAccepted: if (matches.length) settings.chooseSection(matches[0].name)
            }
            SelectBox {
                objectName: "settingsSectionPicker"
                Layout.fillWidth: true
                model: compactSearch.matches
                textRole: "name"
                currentIndex: model.findIndex(it => it.name === settings.section)
                displayText: !model.length ? qsTr("No settings match") : currentIndex < 0 ? qsTr("Choose a section…") : currentText
                Accessible.name: qsTr("Settings section")
                onActivated: settings.chooseSection(model[currentIndex].name)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 24
            SettingsSidebar {
                visible: !settings.compactLayout
                controller: settings.controller
                section: settings.section
                onSectionSelected: nextSection => settings.section = nextSection
            }
            ScrollView {
                id: scroll
                objectName: "settingsScroll"
                Layout.fillWidth: true
                Layout.fillHeight: true
                contentWidth: availableWidth
                clip: true
                ColumnLayout {
                    id: settingsBody
                    objectName: "settingsBody"
                    width: Math.min(980, scroll.availableWidth - 16)
                    x: Math.max(0, (scroll.availableWidth - width) / 2)
                    spacing: 24
                    SettingsBanner {
                        title: settings.section
                        detail: settings.section === "Interface" ? qsTr("How Prismarine looks and what it does while a game runs.")
                            : settings.section === "Library & covers" ? qsTr("Shape your library, covers and artwork.") : settings.section === "Prism integration" ? qsTr("Launcher integration. Changes here apply immediately.") : settings.section === "Launcher mode" ? qsTr("How Prismarine runs, and which parts you want.") : qsTr("Your launcher, your settings.")
                    }
                    InterfaceOptions {
                        controller: appearanceController
                        visible: settings.section === "Interface"
                    }
                    SettingsLayoutPreview {
                        preferences: appearanceDraft
                        visible: settings.section === "Library & covers"
                    }
                    LibraryPreferences {
                        controller: appearanceController
                        section: settings.section
                    }
                    AppearanceSwitches {
                        controller: appearanceController
                        section: settings.section === "Library & covers" ? settings.section : ""
                    }
                    LauncherModeSettings {
                        controller: settings.controller
                        visible: settings.section === "Launcher mode"
                    }
                    PrismIntegrationSettings {
                        controller: settings.controller
                        visible: settings.section === "Prism integration"
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
        Rectangle {
            objectName: "settingsActionBar"
            visible: settings.appearanceSection
            Layout.fillWidth: true
            Layout.maximumWidth: settings.compactLayout ? settingsBody.width : -1
            Layout.alignment: Qt.AlignHCenter
            implicitHeight: footer.implicitHeight + 24
            radius: 14
            color: Colors.surface
            border.color: appearanceDraft.dirty ? Colors.accent : Colors.border
            RowLayout {
                id: footer
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                spacing: 10
                Text { Layout.fillWidth: true; text: appearanceDraft.dirty ? qsTr("Preview changes · Apply to save") : qsTr("Try changes in the preview before applying."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
                ActionButton { objectName: "resetAppearance"; text: qsTr("Defaults"); implicitWidth: 90; onClicked: appearanceDraft.resetDefaults() }
                ActionButton { objectName: "discardAppearance"; text: qsTr("Discard"); implicitWidth: 90; enabled: appearanceDraft.dirty; onClicked: appearanceDraft.load() }
                ActionButton { objectName: "applyAppearance"; text: qsTr("Apply"); implicitWidth: 100; primary: true; enabled: appearanceDraft.dirty; onClicked: appearanceDraft.apply() }
            }
        }
    }
}
