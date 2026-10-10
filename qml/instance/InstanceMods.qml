import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ColumnLayout {
    id: modsTab
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info
    property string modState: "all"
    readonly property var updater: controller.updater
    // Updates found for this instance, keyed by installed file name.
    readonly property var updates: updater && updater.contentType === "mod" && updater.instanceId === contents.instanceId ? updater.byFile : ({})
    readonly property int updateCount: Object.keys(updates).length
    readonly property bool updating: !!updater && updater.state === "updating"
    property var selectedMod: ({})
    // fileName -> true; reassigned on every change so bindings update.
    property var selection: ({})
    readonly property var selectedFiles: Object.keys(selection)
    readonly property var filteredMods: contents.mods.filter(function (mod) {
        return (modState === "all" || (modState === "updates" ? !!updates[mod.fileName] : mod.enabled === (modState === "enabled"))) && (!modSearch.text || (mod.name + " " + mod.fileName + " " + mod.authors).toLowerCase().indexOf(modSearch.text.toLowerCase()) >= 0);
    })
    readonly property int visibleSelected: filteredMods.filter(mod => selection[mod.fileName]).length

    function setSelected(fileName, on) {
        const next = Object.assign({}, selection);
        if (on)
            next[fileName] = true;
        else
            delete next[fileName];
        selection = next;
    }
    function selectVisible(on) {
        const next = Object.assign({}, selection);
        for (const mod of filteredMods) {
            if (on)
                next[mod.fileName] = true;
            else
                delete next[mod.fileName];
        }
        selection = next;
    }
    function applyEnabled(on) {
        const count = contents.setModsEnabled(selectedFiles, on);
        selection = ({});
        if (count)
            controller.notify((on ? "Enabled " : "Disabled ") + count + (count === 1 ? " mod" : " mods"));
    }

    property string selectionOwner: ""
    Component.onCompleted: selectionOwner = contents.instanceId
    // `changed` fires on every refresh: reset only for another instance, otherwise drop vanished files.
    Connections {
        target: modsTab.contents
        function onChanged() {
            if (modsTab.contents.instanceId !== modsTab.selectionOwner) {
                modsTab.selectionOwner = modsTab.contents.instanceId;
                modsTab.selection = ({});
                return;
            }
            const present = new Set(modsTab.contents.mods.map(mod => mod.fileName));
            const kept = modsTab.selectedFiles.filter(name => present.has(name));
            if (kept.length !== modsTab.selectedFiles.length) {
                const next = {};
                for (const name of kept)
                    next[name] = true;
                modsTab.selection = next;
            }
        }
    }

    anchors {
        fill: parent
        margins: 28
    }
    visible: controller.instanceTab === "mods"
    spacing: 14
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Text {
            text: "Mods"
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: 28
            font.letterSpacing: 2
        }
        Text {
            Layout.alignment: Qt.AlignBaseline
            text: (modsTab.info.enabledMods || 0) + " enabled · " + (modsTab.info.disabledMods || 0) + " disabled"
            color: Colors.subtext
            font.pixelSize: 13
        }
        Item {
            Layout.fillWidth: true
        }
        ModProfilesButton {
            controller: modsTab.controller
        }
        ActionButton {
            objectName: "checkUpdatesButton"
            visible: !!modsTab.updater
            text: modsTab.updater && modsTab.updater.state === "checking" && modsTab.updater.instanceId === contents.instanceId ? "Checking…" : "↻ Check for updates"
            implicitWidth: contentItem.implicitWidth + 32
            enabled: !!modsTab.updater && modsTab.updater.state !== "checking" && !modsTab.updating
            onClicked: modsTab.updater.check(contents.instanceId)
        }
        ActionButton {
            visible: modsTab.updateCount > 0
            text: modsTab.updating ? "Updating…" : "Update all (" + modsTab.updateCount + ")"
            implicitWidth: contentItem.implicitWidth + 32
            enabled: !modsTab.updating
            onClicked: modsTab.updater.update([])
        }
        ActionButton {
            text: "Browse mods"
            implicitWidth: contentItem.implicitWidth + 32
            onClicked: controller.navigate("browse")
        }
        ActionButton {
            text: "+ Add mods"
            primary: true
            implicitWidth: contentItem.implicitWidth + 32
            onClicked: modsDialog.open()
        }
    }
    ModHealthPanel {
        controller: modsTab.controller
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 8
        InputField {
            id: modSearch
            objectName: "modSearch"
            Layout.preferredWidth: Math.min(320, modsTab.width * 0.4)
            placeholderText: "Search " + contents.mods.length + " mods…"
            font.pixelSize: 13
        }
        Repeater {
            model: [
                {
                    label: "All",
                    key: "all"
                },
                {
                    label: "Enabled",
                    key: "enabled"
                },
                {
                    label: "Disabled",
                    key: "disabled"
                },
                {
                    label: "Updates",
                    key: "updates"
                }
            ]
            delegate: Chip {
                required property var modelData
                visible: modelData.key !== "updates" || modsTab.updateCount > 0
                text: modelData.key === "updates" ? "Updates " + modsTab.updateCount : modelData.label
                interactive: true
                active: modsTab.modState === modelData.key
                tint: active ? Colors.accent : Colors.text
                onClicked: modsTab.modState = modelData.key
            }
        }
        Item {
            Layout.fillWidth: true
        }
    }
    Rectangle {
        objectName: "modSelectionBar"
        Layout.fillWidth: true
        Layout.preferredHeight: modsTab.selectedFiles.length ? 50 : 0
        visible: Layout.preferredHeight > 0
        clip: true
        radius: 10
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.08)
        border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.4)
        Behavior on Layout.preferredHeight { NumberAnimation { duration: Colors.animations ? 180 : 0; easing.type: Easing.OutCubic } }
        RowLayout {
            anchors {
                fill: parent
                leftMargin: 14
                rightMargin: 14
            }
            spacing: 8
            Text {
                text: modsTab.selectedFiles.length + " selected"
                color: Colors.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
                Layout.rightMargin: 6
            }
            Repeater {
                model: [
                    {
                        label: "Update",
                        action: "update"
                    },
                    {
                        label: "Enable",
                        action: "enable"
                    },
                    {
                        label: "Disable",
                        action: "disable"
                    },
                    {
                        label: "Remove",
                        action: "remove"
                    }
                ]
                delegate: ActionButton {
                    required property var modelData
                    text: modelData.label
                    readonly property var updatable: modsTab.selectedFiles.filter(name => !!modsTab.updates[name])
                    visible: modelData.action !== "update" || updatable.length > 0
                    danger: modelData.action === "remove"
                    implicitWidth: contentItem.implicitWidth + 28
                    implicitHeight: 30
                    font.pixelSize: 12
                    enabled: !contents.loading && !modsTab.updating
                    onClicked: {
                        if (modelData.action === "remove")
                            removeDialog.open();
                        else if (modelData.action === "update") {
                            modsTab.updater.update(updatable);
                            modsTab.selection = ({});
                        } else
                            modsTab.applyEnabled(modelData.action === "enable");
                    }
                }
            }
            Item {
                Layout.fillWidth: true
            }
            TextLink {
                text: "Clear"
                tint: Colors.subtext
                underline: false
                onClicked: modsTab.selection = ({})
            }
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Layout.leftMargin: 14
        Layout.rightMargin: 14
        spacing: 16
        TickBox {
            Accessible.name: "Select all shown mods"
            checked: modsTab.filteredMods.length > 0 && modsTab.visibleSelected === modsTab.filteredMods.length
            partial: modsTab.visibleSelected > 0 && !checked
            onClicked: modsTab.selectVisible(modsTab.visibleSelected < modsTab.filteredMods.length)
        }
        Item {
            Layout.preferredWidth: 34
        }
        Text {
            Layout.fillWidth: true
            text: "Name"
            font.family: Colors.displayFont
            color: Colors.brass
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }
        Text {
            Layout.preferredWidth: 160
            text: "Version"
            font.family: Colors.displayFont
            color: Colors.brass
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }
        Text {
            Layout.preferredWidth: 100
            text: "Side"
            font.family: Colors.displayFont
            color: Colors.brass
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }
        Text {
            Layout.preferredWidth: 66
            text: "On"
            font.family: Colors.displayFont
            color: Colors.brass
            font.pixelSize: 11
            font.letterSpacing: 1.5
        }
    }
    ListView {
        id: modList
        objectName: "modList"
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: modsTab.filteredMods
        spacing: 1
        ScrollBar.vertical: ScrollBar {}
        Rectangle {
            parent: modList
            anchors.fill: parent
            z: 1
            color: "transparent"
            radius: 10
            border.color: Colors.border
        }
        delegate: ModRow {
            controller: modsTab.controller
            availableUpdate: modsTab.updates[modelData.fileName] || null
            selected: !!modsTab.selection[modelData.fileName]
            onSelectToggled: on => modsTab.setSelected(modelData.fileName, on)
            onInspectRequested: mod => {
                modsTab.selectedMod = mod;
                modInfo.open();
            }
        }
        Text {
            anchors.centerIn: parent
            visible: !contents.loading && !modsTab.filteredMods.length
            text: modsTab.modState === "updates" ? "Everything is up to date." : contents.mods.length ? "No matching mods." : "No mods installed."
            color: Colors.subtext
            font.pixelSize: 15
        }
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: modsTab.filteredMods.length + " mods"
            color: Colors.subtext
            font.pixelSize: 12
        }
        Item {
            Layout.fillWidth: true
        }
        ActionButton {
            text: "Open mods folder"
            onClicked: contents.openContentFolder("mods")
        }
    }
    FileDialog {
        id: modsDialog
        title: "Add mods"
        fileMode: FileDialog.OpenFiles
        nameFilters: ["Minecraft mods (*.jar)"]
        onAccepted: contents.addMods(selectedFiles)
    }
    ConfirmDialog {
        id: removeDialog
        objectName: "removeModsDialog"
        anchors.centerIn: parent
        title: "Remove " + modsTab.selectedFiles.length + (modsTab.selectedFiles.length === 1 ? " mod?" : " mods?")
        message: "The files move to your system trash (or the instance's .prismarine-removed folder), so you can restore them later."
        confirmText: "Remove"
        danger: true
        onConfirmed: {
            const count = contents.removeMods(modsTab.selectedFiles);
            modsTab.selection = ({});
            if (count)
                controller.notify("Removed " + count + (count === 1 ? " mod" : " mods"));
        }
    }
    MotionDialog {
        id: modInfo
        anchors.centerIn: parent
        width: Math.min(modsTab.width - 80, 680)
        modal: true
        title: modsTab.selectedMod.name || "Mod details"
        standardButtons: Dialog.Close
        background: Rectangle {
            radius: 14
            color: Colors.surface
            border.color: Colors.border
        }
        contentItem: ColumnLayout {
            spacing: 16
            Text {
                Layout.fillWidth: true
                text: modsTab.selectedMod.name || ""
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: 28
                wrapMode: Text.Wrap
            }
            Text {
                text: "Version " + (modsTab.selectedMod.version || "—")
                color: Colors.accent
                font.pixelSize: 14
            }
            Text {
                Layout.fillWidth: true
                text: modsTab.selectedMod.authors ? "By " + modsTab.selectedMod.authors : "Author not declared"
                color: Colors.subtext
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
            Text {
                Layout.fillWidth: true
                text: modsTab.selectedMod.description || "No description declared in this mod's metadata."
                color: Colors.text
                font.pixelSize: 14
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
            }
            Text {
                Layout.fillWidth: true
                text: modsTab.selectedMod.fileName || ""
                color: Colors.subtext
                font.pixelSize: 12
                wrapMode: Text.WrapAnywhere
            }
        }
    }
}
