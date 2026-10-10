import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Reviews files dropped on the window before anything is copied.
MotionDialog {
    id: dialog
    objectName: "dropInstallDialog"
    required property var controller
    property var files: []
    property string targetId: ""
    readonly property var loose: files.filter(it => ["mod", "resourcepack", "shader", "datapack"].indexOf(it.kind) >= 0)
    readonly property var packs: files.filter(it => it.kind === "modpack")
    readonly property var target: controller.instances.getById(targetId)
    readonly property var worlds: controller.instances.worlds.filter(it => it.instanceId === targetId)
    readonly property bool needsWorld: loose.some(it => it.kind === "datapack")
    readonly property var kindLabels: ({ mod: "Mod", resourcepack: "Resource pack", shader: "Shader", datapack: "Datapack", modpack: "Modpack", unknown: "Not supported" })
    readonly property var kindIcons: ({ mod: "package", resourcepack: "library", shader: "shaders", datapack: "world", modpack: "plus", unknown: "close" })
    function openFor(list, id) {
        files = list;
        const all = controller.instances.allInstances;
        targetId = id && controller.instances.getById(id).instanceId ? id : (all.length ? all[0].instanceId : "");
        open();
    }
    function packIndex(file) {
        return packs.findIndex(it => String(it.url) === String(file.url));
    }
    function warning(file) {
        if (file.kind === "modpack")
            return packIndex(file) === 0 ? "Imports as a new instance" : "Import one pack at a time";
        if (file.kind === "unknown") return "Skipped";
        if (!target.instanceId) return "";
        if (file.kind === "datapack" && !worlds.length) return "This instance has no worlds yet";
        if (file.kind !== "mod") return "";
        if (target.loader === "Vanilla") return "Vanilla can't load mods";
        if (file.loaders && file.loaders.length && !controller.drops.loaderMatches(file.loaders, target.loader))
            return "Made for " + file.loaders.join(" / ");
        return "";
    }
    function install() {
        let result = { installed: 0, skipped: [] };
        if (loose.length) {
            if (controller.instanceBusy(targetId)) return;
            result = controller.drops.install(targetId, loose.map(it => it.url), needsWorld && worlds.length ? worldBox.currentText : "");
        }
        const pack = packs.length ? packs[0].url : null;
        close();
        if (result.installed)
            controller.notify("Added " + result.installed + (result.installed === 1 ? " file" : " files") + " to " + target.name);
        if (result.skipped.length)
            controller.notify(result.skipped.length + " skipped — " + result.skipped[0].fileName + ": " + result.skipped[0].reason, true);
        if (pack) controller.importDroppedPack(pack);
    }
    title: "Add dropped files"
    subtitle: loose.length ? "Check where these files go. Nothing is copied until you confirm."
                           : packs.length ? "Modpacks are imported as new instances." : "None of these files can be installed."
    width: Math.min(640, controller.width - 64)
    modal: true
    contentItem: ColumnLayout {
        spacing: 14
        GridLayout {
            Layout.fillWidth: true
            visible: dialog.loose.length > 0
            columns: dialog.needsWorld ? 2 : 1
            columnSpacing: 12
            rowSpacing: 8
            Text { text: "INSTANCE"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 12; font.letterSpacing: 2 }
            Text { visible: dialog.needsWorld; text: "WORLD FOR DATAPACKS"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 12; font.letterSpacing: 2 }
            SelectBox {
                id: instanceBox
                objectName: "dropTargetInstance"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                model: dialog.controller.instances.allInstances
                textRole: "name"
                Accessible.name: "Instance"
                currentIndex: Math.max(0, dialog.controller.instances.allInstances.findIndex(it => it.instanceId === dialog.targetId))
                onActivated: index => dialog.targetId = dialog.controller.instances.allInstances[index].instanceId
            }
            SelectBox {
                id: worldBox
                visible: dialog.needsWorld
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                enabled: dialog.worlds.length > 0
                model: dialog.worlds.length ? dialog.worlds.map(it => it.name) : ["No worlds"]
                Accessible.name: "World"
            }
        }
        Rectangle {
            Layout.fillWidth: true
            Layout.preferredHeight: Math.min(list.contentHeight + 12, 300)
            radius: 12
            color: Colors.inset
            border.color: Colors.border
            ListView {
                id: list
                anchors { fill: parent; margins: 6 }
                clip: true
                spacing: 2
                model: dialog.files
                ScrollBar.vertical: ScrollBar {}
                delegate: Rectangle {
                    id: row
                    required property var modelData
                    required property int index
                    readonly property string note: dialog.warning(modelData)
                    readonly property bool skipped: modelData.kind === "unknown" || (modelData.kind === "modpack" && dialog.packIndex(modelData) > 0)
                    width: ListView.view.width
                    height: 54
                    radius: 8
                    color: index % 2 ? "transparent" : Colors.rowAlt
                    RowLayout {
                        anchors { fill: parent; leftMargin: 10; rightMargin: 12 }
                        spacing: 12
                        opacity: row.skipped ? 0.55 : 1
                        Rectangle {
                            implicitWidth: 34
                            implicitHeight: 34
                            radius: 8
                            color: Colors.surfaceHi
                            Image {
                                id: art
                                anchors.fill: parent
                                source: row.modelData.icon || ""
                                fillMode: Image.PreserveAspectFit
                                visible: status === Image.Ready
                            }
                            LineIcon {
                                anchors.centerIn: parent
                                visible: art.status !== Image.Ready
                                name: dialog.kindIcons[row.modelData.kind] || "package"
                                tint: row.modelData.kind === "unknown" ? Colors.subtext : Colors.accent
                                implicitWidth: 18
                                implicitHeight: 18
                            }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.name || row.modelData.fileName
                                color: Colors.text
                                font.pixelSize: 14
                                font.weight: Font.DemiBold
                                elide: Text.ElideRight
                            }
                            Text {
                                Layout.fillWidth: true
                                text: row.modelData.fileName
                                color: Colors.subtext
                                font.pixelSize: 11
                                elide: Text.ElideMiddle
                            }
                        }
                        Text {
                            visible: !!row.note
                            Layout.maximumWidth: 180
                            text: row.note
                            color: row.modelData.kind === "modpack" && !row.skipped ? Colors.accent : row.skipped ? Colors.subtext : Colors.warning
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Chip {
                            text: dialog.kindLabels[row.modelData.kind] || "File"
                            tint: row.modelData.kind === "unknown" ? Colors.subtext : row.modelData.kind === "modpack" ? Colors.brass : Colors.accent
                        }
                    }
                }
            }
        }
    }
    footer: DialogActions {
        confirmName: "confirmDrop"
        confirmWidth: 190
        confirmEnabled: dialog.loose.length > 0 ? !!dialog.target.instanceId : dialog.packs.length > 0
        confirmText: dialog.loose.length ? "Add " + dialog.loose.length + (dialog.loose.length === 1 ? " file" : " files") + (dialog.packs.length ? " + import" : "")
                                         : dialog.packs.length ? "Import pack" : "Nothing to add"
        onCancelled: dialog.close()
        onConfirmed: dialog.install()
    }
}
