import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Settings → Storage: where Prism's disk space goes, with cleanup of regenerable data.
ColumnLayout {
    id: panel
    required property var controller
    readonly property var storage: controller.storage
    readonly property var cleanableKeys: ["logs", "caches", "removed", "backups"]
    spacing: 20

    // Folds an instance's categories into the chart's fixed slots.
    function instanceSegments(categories) {
        const size = keys => categories.filter(it => keys.indexOf(it.key) >= 0).reduce((total, it) => total + it.size, 0);
        return [
            { label: "Worlds", size: size(["worlds"]), color: Colors.series[0] },
            { label: "Mods", size: size(["mods"]), color: Colors.series[1] },
            { label: "Packs & shaders", size: size(["resourcepacks", "shaderpacks"]), color: Colors.series[2] },
            { label: "Screenshots", size: size(["screenshots"]), color: Colors.series[3] },
            { label: "Logs, caches & leftovers", size: size(cleanableKeys), color: Colors.series[4] },
            { label: "Other files", size: size(["other"]), color: Colors.seriesOther }
        ];
    }
    readonly property var overall: {
        if (!storage) return [];
        const totals = instanceSegments([]);
        for (const entry of storage.instances) {
            const parts = instanceSegments(entry.categories);
            for (let i = 0; i < parts.length; ++i) totals[i].size += parts[i].size;
        }
        const shared = storage.shared.reduce((total, it) => total + it.size, 0);
        totals.splice(5, 0, { label: "Launcher files", size: shared, color: Colors.series[5] });
        return totals;
    }
    readonly property real cleanable: storage ? storage.instances.reduce((total, entry) =>
        total + entry.categories.filter(it => panel.cleanableKeys.indexOf(it.key) >= 0).reduce((sum, it) => sum + it.size, 0), 0) : 0

    property var pendingClean: null
    function askClean(entry, keys) {
        pendingClean = { instanceId: entry.instanceId, keys: keys };
        const labels = entry.categories.filter(it => keys.indexOf(it.key) >= 0);
        const size = labels.reduce((total, it) => total + it.size, 0);
        confirm.title = "Clean " + entry.name + "?";
        confirm.message = "Removes " + labels.map(it => it.label.toLowerCase()).join(", ") + " (" + Colors.formatBytes(size) + ")."
            + (keys.indexOf("screenshots") >= 0 ? " Screenshots go to the system trash." : "")
            + (keys.indexOf("backups") >= 0 ? " Version backups let you undo Minecraft or loader changes; they cannot be restored once removed." : "")
            + " Logs and caches are deleted permanently and are recreated when you play.";
        confirm.confirmText = "Clean " + Colors.formatBytes(size);
        confirm.open();
    }
    function askTrashWorld(entry, world) {
        pendingClean = { instanceId: entry.instanceId, world: world.name };
        confirm.title = "Move “" + world.name + "” to the trash?";
        confirm.message = "The world folder (" + Colors.formatBytes(world.size) + ") moves to the system trash, where you can restore it. Space is freed when the trash is emptied.";
        confirm.confirmText = "Move to trash";
        confirm.open();
    }
    function cleanEverything() {
        let freed = 0;
        for (const entry of storage.instances) {
            const keys = entry.categories.filter(it => ["logs", "caches", "removed"].indexOf(it.key) >= 0 && it.size > 0).map(it => it.key);
            if (keys.length) freed += storage.clean(entry.instanceId, keys);
        }
        controller.notify(freed ? "Freed " + Colors.formatBytes(freed) : "Nothing to clean");
    }

    Text {
        visible: !panel.storage
        text: "Storage details are not available in this window."
        color: Colors.subtext
    }

    // Overview
    Rectangle {
        Layout.fillWidth: true
        visible: !!panel.storage
        implicitHeight: overview.implicitHeight + 40
        radius: 14
        color: Colors.mantle
        border.color: Colors.border
        ColumnLayout {
            id: overview
            anchors { fill: parent; margins: 20 }
            spacing: 14
            RowLayout {
                Layout.fillWidth: true
                spacing: 16
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: panel.storage && panel.storage.total ? Colors.formatBytes(panel.storage.total) : panel.storage && panel.storage.loading ? "Measuring…" : "—"
                        color: Colors.bone
                        font.family: Colors.displayFont
                        font.pixelSize: 34
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "used by Prism instances and launcher files"
                              + (panel.storage && panel.storage.diskSize ? " · " + Colors.formatBytes(panel.storage.diskFree) + " free of " + Colors.formatBytes(panel.storage.diskSize) + " on this drive" : "")
                        color: Colors.subtext
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                }
                BusyIndicator {
                    running: !!panel.storage && panel.storage.loading
                    visible: running
                    implicitWidth: 28
                    implicitHeight: 28
                }
                ActionButton {
                    text: "Rescan"
                    implicitWidth: 110
                    enabled: !!panel.storage && !panel.storage.loading
                    onClicked: panel.storage.scan()
                }
                ActionButton {
                    objectName: "cleanAllStorage"
                    primary: true
                    implicitWidth: 200
                    visible: panel.cleanable > 0
                    text: "Clean logs & caches"
                    enabled: !!panel.storage && !panel.storage.loading
                    onClicked: {
                        panel.pendingClean = { all: true };
                        confirm.title = "Clean every instance?";
                        confirm.message = "Deletes logs, crash reports, loader caches and previously removed mods or datapacks in all instances. Worlds, screenshots and version backups are kept. Running instances are skipped.";
                        confirm.confirmText = "Clean all";
                        confirm.open();
                    }
                }
            }
            StorageBar {
                Layout.fillWidth: true
                barHeight: 16
                gapColor: Colors.mantle
                segments: panel.overall
            }
            Flow {
                Layout.fillWidth: true
                spacing: 18
                Repeater {
                    model: panel.overall
                    delegate: Row {
                        required property var modelData
                        spacing: 7
                        Rectangle { width: 10; height: 10; radius: 3; color: modelData.color; anchors.verticalCenter: parent.verticalCenter }
                        Text { text: modelData.label; color: Colors.text; font.pixelSize: 12 }
                        Text { text: Colors.formatBytes(modelData.size); color: Colors.subtext; font.pixelSize: 12 }
                    }
                }
            }
        }
    }

    // Launcher-wide folders
    ColumnLayout {
        Layout.fillWidth: true
        visible: !!panel.storage && panel.storage.shared.length > 0
        spacing: 8
        Text { text: "LAUNCHER FILES"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 12; font.letterSpacing: 2 }
        Text {
            Layout.fillWidth: true
            text: "Shared by every instance and managed by Prism. Only the download cache is safe to clear, and only while Prism is closed."
            color: Colors.subtext
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        GridLayout {
            Layout.fillWidth: true
            columns: panel.width >= 760 ? 5 : 3
            columnSpacing: 10
            rowSpacing: 10
            Repeater {
                model: panel.storage ? panel.storage.shared : []
                delegate: Rectangle {
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 78
                    radius: 12
                    color: Colors.surface
                    border.color: Colors.border
                    ColumnLayout {
                        anchors { fill: parent; margins: 12 }
                        spacing: 2
                        Text { Layout.fillWidth: true; text: modelData.label; color: Colors.subtext; font.pixelSize: 12; elide: Text.ElideRight }
                        RowLayout {
                            Layout.fillWidth: true
                            Text { Layout.fillWidth: true; text: Colors.formatBytes(modelData.size); color: Colors.text; font.pixelSize: 18; font.weight: Font.DemiBold }
                            TextLink {
                                visible: modelData.cleanable && modelData.size > 0
                                text: "Clear"
                                pixelSize: 13
                                onClicked: {
                                    // Clearing refreshes this list and destroys this card, so keep the controller first.
                                    const controller = panel.controller;
                                    const freed = panel.storage.clearLauncherCache();
                                    if (freed) controller.notify("Freed " + Colors.formatBytes(freed));
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    // Shared content (optional hard links)
    Rectangle {
        id: sharingCard
        Layout.fillWidth: true
        visible: !!panel.storage
        readonly property var sharing: panel.storage ? panel.storage.sharing : ({})
        implicitHeight: sharingBody.implicitHeight + 36
        radius: 14
        color: Colors.surface
        border.color: Colors.border
        ColumnLayout {
            id: sharingBody
            anchors { fill: parent; margins: 18 }
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                spacing: 10
                Text { text: "Shared content"; color: Colors.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                Chip { text: "OPTIONAL"; tint: Colors.subtext }
                Item { Layout.fillWidth: true }
                Text {
                    visible: (sharingCard.sharing.sharedFiles || 0) > 0
                    text: sharingCard.sharing.sharedFiles + " files shared · saving " + Colors.formatBytes(sharingCard.sharing.saved)
                    color: Colors.success
                    font.pixelSize: 13
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Identical mods, resource packs and shaders in several instances can be stored once. Each instance keeps its own file name (a hard link), so disabling, updating or deleting a mod in one instance never changes another. Instances that are running are skipped."
                color: Colors.subtext
                font.pixelSize: 12
                wrapMode: Text.Wrap
                lineHeight: 1.2
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 12
                BusyIndicator { visible: !!sharingCard.sharing.checking; running: visible; implicitWidth: 22; implicitHeight: 22 }
                Text {
                    Layout.fillWidth: true
                    text: sharingCard.sharing.checking ? "Comparing files…"
                        : !sharingCard.sharing.checked ? "Check how much space identical files take."
                        : sharingCard.sharing.duplicates ? sharingCard.sharing.duplicates + " duplicate files could free " + Colors.formatBytes(sharingCard.sharing.savings) + "."
                        : "No unshared duplicates found."
                    color: Colors.text
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }
                TextLink {
                    visible: (sharingCard.sharing.sharedFiles || 0) > 0
                    text: "Stop sharing"
                    pixelSize: 13
                    onClicked: {
                        panel.pendingClean = { unshare: true };
                        confirm.title = "Stop sharing files?";
                        confirm.message = "Every shared file becomes a separate copy again in each instance, using " + Colors.formatBytes(sharingCard.sharing.saved) + " more space. Nothing is removed.";
                        confirm.confirmText = "Make separate copies";
                        confirm.open();
                    }
                }
                ActionButton {
                    objectName: "findDuplicates"
                    visible: !sharingCard.sharing.checked || !sharingCard.sharing.duplicates
                    text: "Find identical files"
                    enabled: !sharingCard.sharing.checking
                    onClicked: panel.storage.findDuplicates()
                }
                ActionButton {
                    objectName: "shareDuplicates"
                    visible: !!sharingCard.sharing.checked && sharingCard.sharing.duplicates > 0
                    primary: true
                    text: "Share " + (sharingCard.sharing.duplicates || 0) + " files"
                    onClicked: {
                        panel.pendingClean = { share: true };
                        confirm.title = "Share identical files?";
                        confirm.message = "Duplicates are replaced, one at a time, by links to a single copy after their contents are compared again. Instances behave exactly as before. You can stop sharing at any time.";
                        confirm.confirmText = "Share files";
                        confirm.open();
                    }
                }
            }
        }
    }

    // Per instance
    ColumnLayout {
        Layout.fillWidth: true
        visible: !!panel.storage && panel.storage.instances.length > 0
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "INSTANCES"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 12; font.letterSpacing: 2 }
            InputField {
                id: storageSearch
                objectName: "storageSearch"
                visible: !!panel.storage && panel.storage.instances.length > 5
                Layout.preferredWidth: 240
                implicitHeight: 34
                font.pixelSize: 13
                placeholderText: "Filter instances…"
            }
        }
        Repeater {
            model: !panel.storage ? [] : panel.storage.instances.filter(it => !storageSearch.text || it.name.toLowerCase().indexOf(storageSearch.text.trim().toLowerCase()) >= 0)
            delegate: StorageInstanceRow {
                required property var modelData
                Layout.fillWidth: true
                host: panel
                entry: modelData
                largest: panel.storage.instances.length ? panel.storage.instances[0].total : 1
            }
        }
    }

    ConfirmDialog {
        id: confirm
        objectName: "storageConfirm"
        parent: Overlay.overlay
        anchors.centerIn: parent
        danger: !(panel.pendingClean && (panel.pendingClean.share || panel.pendingClean.unshare))
        onConfirmed: {
            const job = panel.pendingClean;
            panel.pendingClean = null;
            if (!job) return;
            if (job.all) { panel.cleanEverything(); return; }
            if (job.share) {
                const result = panel.storage.shareDuplicates();
                panel.controller.notify(result.linked ? "Shared " + result.linked + " files · freed " + Colors.formatBytes(result.freed) : "Nothing was shared", !result.linked);
                panel.storage.scan();
                return;
            }
            if (job.unshare) {
                const count = panel.storage.unshareAll();
                panel.controller.notify(count ? "Made " + count + " separate copies" : "Nothing was shared");
                panel.storage.scan();
                return;
            }
            if (job.world) {
                if (panel.storage.trashWorld(job.instanceId, job.world)) panel.controller.notify("World moved to the trash");
                return;
            }
            const freed = panel.storage.clean(job.instanceId, job.keys);
            panel.controller.notify(freed ? "Freed " + Colors.formatBytes(freed) : "Nothing was removed");
        }
    }
}
