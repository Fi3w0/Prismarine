import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MotionDialog {
    id: dialog
    objectName: "versionDialog"
    required property var controller
    property string editId: ""
    property string initialMinecraft: ""
    property string initialLoaderVersion: ""
    property string loaderName: "Vanilla"
    readonly property var loaders: [
        { name: "Vanilla", caption: "The game as Mojang ships it" },
        { name: "Fabric", caption: "Lightweight, fast updates" },
        { name: "Quilt", caption: "Fabric-compatible fork" },
        { name: "NeoForge", caption: "Modern large modpacks" },
        { name: "Forge", caption: "Classic and older packs" }
    ]
    readonly property string suggestedName: (loaderName === "Vanilla" ? "Minecraft" : loaderName) + (minecraft.currentText ? " " + minecraft.currentText : "")
    readonly property string chosenName: instanceName.text.trim() || suggestedName
    function openFor(id) {
        if (creator.loading) return;
        if (id && !creator.beginEdit(id)) { controller.notify(creator.error, true); return; }
        editId = id;
        open();
    }
    property string loaderRequestKey: ""
    function selectLoader() {
        if (!visible || creator.loading || !creator.versions.length)
            return;
        const key = minecraft.currentText + "|" + loaderName;
        if (key === loaderRequestKey)
            return;
        loaderRequestKey = key;
        creator.loadLoader(loaderName, minecraft.currentText);
    }
    function submit() {
        if (!footer.confirmEnabled) return;
        if (editId) {
            if (controller.instanceBusy(editId)) return;
            if (creator.changeVersions(minecraft.currentText, loaderName, loaderVersion.currentText)) {
                controller.notify("Versions updated"); close();
            }
            return;
        }
        const id = creator.create(chosenName, minecraft.currentText, loaderName, loaderVersion.currentText);
        if (id) {
            close();
            controller.selectId(id);
            controller.openInstance(id);
            controller.notify("Instance created");
        }
    }
    readonly property var creator: controller.creator
    title: editId ? "Change versions" : "New instance"
    subtitle: editId ? "Pick the Minecraft and loader versions for " + (controller.instances.getById(editId).name || "this instance") + "."
                     : "Choose a loader and a Minecraft version. Game files download the first time you play."
    width: Math.min(760, controller.width - 64)
    modal: true
    onOpened: {
        loaderRequestKey = "";
        const info = controller.instances.getById(editId);
        initialMinecraft = info.version || "";
        initialLoaderVersion = info.loaderVersion || "";
        loaderName = info.loader && loaders.some(it => it.name === info.loader) ? info.loader : "Vanilla";
        instanceName.text = info.name || "";
        if (editId) snapshots.checked = true;
        creator.loadVersions(snapshots.checked);
        if (!editId) instanceName.forceActiveFocus();
    }
    onLoaderNameChanged: selectLoader()
    Connections {
        target: dialog.creator
        function onChanged() {
            Qt.callLater(function() {
                if (!dialog.visible || dialog.creator.loading) return;
                if (dialog.initialMinecraft && dialog.creator.versions.length) {
                    minecraft.currentIndex = Math.max(0, dialog.creator.versions.findIndex(it => it.version === dialog.initialMinecraft));
                    dialog.initialMinecraft = "";
                }
                dialog.selectLoader();
                if (!dialog.creator.loading && dialog.creator.loaderVersions.length && dialog.initialLoaderVersion) {
                    loaderVersion.currentIndex = Math.max(0, dialog.creator.loaderVersions.findIndex(it => it.version === dialog.initialLoaderVersion));
                    dialog.initialLoaderVersion = "";
                }
            });
        }
    }
    component FieldLabel: Text {
        color: Colors.brass
        font.family: Colors.displayFont
        font.pixelSize: 12
        font.letterSpacing: 2
    }
    contentItem: ColumnLayout {
        spacing: 10
        FieldLabel { text: "NAME"; visible: !dialog.editId }
        InputField {
            id: instanceName
            visible: !dialog.editId
            objectName: "newInstanceName"
            Layout.fillWidth: true
            placeholderText: dialog.suggestedName
            Accessible.name: "Instance name"
            onAccepted: dialog.submit()
        }
        FieldLabel { text: "MOD LOADER"; Layout.topMargin: dialog.editId ? 0 : 10 }
        GridLayout {
            Layout.fillWidth: true
            columns: dialog.width >= 700 ? 5 : 3
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: dialog.loaders
                delegate: AbstractButton {
                    id: tile
                    required property var modelData
                    readonly property bool chosen: dialog.loaderName === modelData.name
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 78
                    padding: 12
                    hoverEnabled: true
                    checkable: true
                    checked: chosen
                    enabled: !dialog.creator.loading
                    Accessible.name: modelData.name
                    onClicked: dialog.loaderName = modelData.name
                    background: Rectangle {
                        radius: 12
                        color: tile.chosen ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12) : tile.hovered ? Colors.surfaceHi : Colors.inset
                        border.width: tile.chosen || tile.activeFocus ? 2 : 1
                        border.color: tile.chosen || tile.activeFocus ? Colors.accent : Colors.border
                        Behavior on color { ColorAnimation { duration: Colors.animations ? 150 : 0 } }
                    }
                    contentItem: ColumnLayout {
                        spacing: 4
                        opacity: tile.enabled ? 1 : 0.5
                        RowLayout {
                            spacing: 8
                            Rectangle {
                                width: 10; height: 10; radius: 3
                                rotation: 45
                                color: tile.modelData.name === "Vanilla" ? Colors.success : Colors.loaderColor(tile.modelData.name)
                            }
                            Text {
                                Layout.fillWidth: true
                                text: tile.modelData.name
                                color: Colors.text
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                        }
                        Text {
                            Layout.fillWidth: true
                            text: tile.modelData.caption
                            color: Colors.subtext
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                    }
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 10
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 8
                RowLayout {
                    FieldLabel { text: "MINECRAFT"; Layout.fillWidth: true }
                    ToggleSwitch {
                        id: snapshots
                        text: "Snapshots"
                        onToggled: {
                            dialog.loaderRequestKey = "";
                            dialog.creator.loadVersions(checked);
                        }
                    }
                }
                SelectBox {
                    id: minecraft
                    Layout.fillWidth: true
                    model: dialog.creator.versions
                    textRole: "version"
                    enabled: !dialog.creator.loading
                    Accessible.name: "Minecraft version"
                    onActivated: dialog.selectLoader()
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                spacing: 8
                FieldLabel {
                    Layout.preferredHeight: snapshots.implicitHeight
                    verticalAlignment: Text.AlignVCenter
                    text: dialog.loaderName === "Vanilla" ? "LOADER VERSION" : dialog.loaderName.toUpperCase() + " VERSION"
                }
                SelectBox {
                    id: loaderVersion
                    Layout.fillWidth: true
                    model: dialog.creator.loaderVersions
                    textRole: "version"
                    visible: dialog.loaderName !== "Vanilla"
                    enabled: !dialog.creator.loading
                    Accessible.name: dialog.loaderName + " version"
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: 40
                    visible: dialog.loaderName === "Vanilla"
                    radius: 10
                    color: Colors.inset
                    border.color: Colors.border
                    Text {
                        anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                        verticalAlignment: Text.AlignVCenter
                        text: "Not needed for Vanilla"
                        color: Colors.subtext
                        font.pixelSize: 13
                        elide: Text.ElideRight
                    }
                }
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.topMargin: 12
            implicitHeight: notice.implicitHeight + 24
            radius: 10
            color: dialog.creator.error ? Qt.rgba(Colors.danger.r, Colors.danger.g, Colors.danger.b, 0.1) : Colors.inset
            border.color: dialog.creator.error ? Qt.rgba(Colors.danger.r, Colors.danger.g, Colors.danger.b, 0.4) : Colors.border
            RowLayout {
                id: notice
                anchors { fill: parent; margins: 12; leftMargin: 14 }
                spacing: 12
                BusyIndicator {
                    running: dialog.creator.loading
                    visible: running
                    implicitWidth: 22
                    implicitHeight: 22
                }
                Text {
                    Layout.fillWidth: true
                    text: dialog.creator.error ? dialog.creator.error
                        : dialog.creator.loading ? "Loading versions…"
                        : dialog.editId ? "Stop the game before applying. Mods and worlds may need matching versions — duplicate the instance before upgrading a world. The previous version manifest is kept in the instance folder."
                        : "Will be created as “" + dialog.chosenName + "” with " + (dialog.loaderName === "Vanilla" ? "no mod loader" : dialog.loaderName + " " + loaderVersion.currentText) + "."
                    color: dialog.creator.error ? Colors.danger : Colors.subtext
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                    lineHeight: 1.2
                }
            }
        }
    }
    footer: DialogActions {
        confirmName: "createInstance"
        confirmWidth: 170
        confirmText: dialog.editId ? "Apply versions" : "Create instance"
        confirmEnabled: (!!dialog.editId || dialog.chosenName.length > 0) && !dialog.creator.loading && dialog.creator.versions.length > 0 && (dialog.loaderName === "Vanilla" || dialog.creator.loaderVersions.length > 0)
        onCancelled: dialog.close()
        onConfirmed: dialog.submit()
        TextLink {
            visible: !dialog.editId
            text: "Browse modpacks"
            pixelSize: 13
            onClicked: { dialog.close(); dialog.controller.browsePacks(); }
        }
        TextLink {
            visible: !dialog.editId
            text: "Import a pack file"
            pixelSize: 13
            onClicked: { dialog.close(); dialog.controller.importPack(); }
        }
    }
}
