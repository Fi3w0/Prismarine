import QtQuick

// Importing packs, dropped files, install reviews and opening Browse for something.
QtObject {
    required property var controller

    function importPack() {
        controller.dialogs.packImport.open();
    }
    function importDroppedPack(url) {
        if (controller.packImporter.state === "extracting" || controller.packImporter.state === "downloading" || controller.packImporter.state === "fetching") {
            controller.notify("Wait for the current import to finish.", true);
            return;
        }
        controller.packImporter.importFile(url);
        controller.dialogs.packImport.open();
    }
    // Files dropped on the window or on one instance. A single modpack imports directly;
    // anything else is reviewed first.
    function handleDrop(urls, targetId) {
        if (!controller.drops || !urls || !urls.length) return;
        const files = controller.drops.inspect(urls);
        const packs = files.filter(it => it.kind === "modpack");
        if (files.length === 1 && packs.length === 1) {
            importDroppedPack(packs[0].url);
            return;
        }
        controller.dialogs.drop.openFor(files, targetId || (controller.page === "instance" ? controller.details.instanceId : controller.current.instanceId));
    }
    function installPackVersion(version) { controller.packImporter.importVersion(version); controller.dialogs.packImport.open(); }
    function reviewSelection(id, type, world) {
        controller.dialogs.installReview.retryInstanceId = "";
        controller.installingType = type;
        controller.installer.prepareMany(id, controller.downloads.items(id, type).map(it => it.version), type, world || "");
        controller.dialogs.installReview.open();
    }
    function reviewInstall(id, version, type, world) {
        if (controller.instanceBusy(id)) return;
        controller.dialogs.installReview.retryInstanceId = "";
        controller.installingType = "";
        controller.installer.prepare(id, version, type, world || "");
        controller.dialogs.installReview.open();
    }
    function reviewLaunchFix(id, project) {
        if (controller.instanceBusy(id)) return false;
        if (controller.instances.isRunning(id) || ["resolving", "ready", "downloading"].indexOf(controller.installer.state) >= 0) {
            controller.notify("Stop the game and finish any content installation before installing a fix.", true);
            return false;
        }
        // A repair does not consume the user's separate Browse selection.
        controller.installingType = "";
        controller.dialogs.installReview.retryInstanceId = id;
        controller.dialogs.installReview.repairProject = project;
        controller.dialogs.installReview.repairDetail = controller.dialogs.launchOverlay.finding.detail || "";
        controller.installer.prepareProject(id, project);
        controller.dialogs.installReview.open();
        return true;
    }
    function browsePacks() {
        if (controller.page === "browse" && controller.pageItem) {
            controller.pageItem.chooseType("modpack");
        } else {
            controller.pendingBrowseType = "modpack";
            controller.navigate("browse");
        }
    }
    function browseDatapacks(id, world) { controller.details.load(id); controller.pendingBrowseType = "datapack"; controller.pendingBrowseWorld = world; controller.navigate("browse"); }
    function browseFor(id, text) {
        if (id && controller.details.instanceId !== id)
            controller.details.load(id);
        controller.pendingBrowseQuery = text;
        controller.navigate("browse");
    }
}
