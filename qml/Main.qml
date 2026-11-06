import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ApplicationWindow {
    id: appWindow
    required property var instances
    required property var preferences
    required property var details
    required property var catalog
    required property var launchSettings
    required property var creator
    required property var accountManager
    required property var packImporter
    required property var installer
    // Optional services: tests run without network news or game tracking.
    property var applicationTheme: null
    property var javaManager: null
    property var news: null
    property var session: null
    property var updater: null
    property var packExporter: null
    property var serverList: null
    property var playtime: null
    property var social: null
    property var storage: null
    property var drops: null
    property var modHealth: null
    property var altLaunch: null
    property var network: null
    property var homeServers: null
    property var appInfo: ({})
    property var launchProgress: null
    property var desktop: null
    property var launcherMode: null
    property var gamepad: null
    readonly property alias dialogs: dialogHost
    // True while a controller action is delivered as a key.
    property bool gamepadKey: false
    // The control a controller is adjusting right now.
    property var gamepadEditItem: null
    readonly property bool friendsEnabled: preferences.friendsEnabled
    onFriendsEnabledChanged: {
        if (friendsEnabled) return;
        if (social) social.setDiscovering(false);
        if (page === "friends") navigate("home");
    }
    readonly property bool prismShortcuts: preferences.prismShortcuts
    property var games: null
    // Command-line helpers for checking layouts: --dialog and --section.
    property string debugDialog: ""
    property string settingsSection: ""
    width: 1400
    height: 875
    minimumWidth: 960
    minimumHeight: 640
    visible: true
    title: "Prismarine"
    color: Colors.base
    palette.window: Colors.surface
    palette.windowText: Colors.text
    palette.text: Colors.text
    palette.buttonText: Colors.text
    palette.base: Colors.mantle
    palette.button: Colors.surfaceHi
    palette.highlight: Colors.accent
    palette.highlightedText: Colors.base
    palette.placeholderText: Colors.subtext
    // Basic sliders, progress bars and busy indicators draw with these roles.
    palette.dark: Colors.accent
    palette.midlight: Colors.outline
    palette.mid: Colors.outline
    palette.light: Colors.surfaceHi
    property string page: "library"
    property bool showFirstRun: !preferences.firstRunSeen
    property string instanceTab: "overview"
    // Now playing's first tab: "" follows the launched game, "all" shows the hardware view.
    property string sessionTab: ""
    property int selected: -1
    property var current: ({})
    property string loaderFilter: ""
    property string searchText: ""
    onSearchTextChanged: instances.setFilter(searchText, loaderFilter)
    property bool rowsView: preferences.libraryView === "rows"
    readonly property bool showScreenshots: preferences.showScreenshots
    readonly property bool hasSelection: selected >= 0 && selected < instances.count
    property bool reefCrownAwake: false
    readonly property string logoFile: reefCrownAwake ? "shard-k.svg" : "shard-o.svg"

    DownloadSelection { id: downloadSelection }
    readonly property var downloads: downloadSelection
    property string installingType: ""
    NavigationHistory { id: history; controller: appWindow }
    readonly property bool canGoBack: history.canGoBack
    function navigate(page) { history.visit(page); }
    function back() { history.back(); }
    // Controller buttons that act on the page rather than the focused control.
    function gamepadAction(action) {
        if (action === "back") { if (canGoBack) back(); return; }
        if (action === "menu") {
            if (hasSelection) play(current.instanceId, current.name); else navigate("library");
            return;
        }
        if (action === "details") { if (hasSelection) openInstance(current.instanceId); return; }
        if (action === "context") {
            if (page === "library" && hasSelection) showInstanceMenu(current.instanceId, current.name, activeFocusItem);
            return;
        }
        const pages = ["home", "library", "browse"].concat(social && friendsEnabled ? ["friends"] : []).concat(session ? ["session"] : []).concat(["settings"]);
        const index = pages.indexOf(page);
        const step = action === "nextPage" ? 1 : -1;
        navigate(pages[index < 0 ? 0 : (index + step + pages.length) % pages.length]);
    }
    function openTab(tab) { openInstance(details.instanceId, tab); }
    function editSettings(id) {
        launchSettings.load(id);
        dialogHost.instanceSettings.open();
    }
    function renameInstance(id) { dialogHost.rename.openFor(id); }
    function saveModProfile() {
        const current = details.profiles.find(it => it.current);
        dialogHost.profilePrompt.ask(current ? current.name : "");
    }
    // Dragging an instance (card, row or sidebar entry) onto a sidebar group header.
    property string draggingId: ""
    property string draggingName: ""
    function beginDrag(instance, scenePosition) {
        draggingName = instance.name;
        moveDrag(scenePosition);
        draggingId = instance.instanceId;
    }
    function moveDrag(scenePosition) {
        dragGhost.x = scenePosition.x - 14;
        dragGhost.y = scenePosition.y - dragGhost.height / 2;
    }
    function endDrag() {
        if (draggingId) dragGhost.Drag.drop();
        draggingId = "";
    }
    function openPalette() { dialogHost.commandPalette.openPalette(); }
    // Instance artwork per slot ("card" or "hero"); see AppPreferences::setArtwork.
    function artworkOf(id, slot) {
        const entry = id ? preferences.artwork[id] : null;
        return entry && entry[slot] ? entry[slot] : { mode: "" };
    }
    function coverFor(id, slot) {
        const choice = artworkOf(id, slot);
        return choice.mode === "image" ? choice.url : "";
    }
    function screenshotFor(id, slot) {
        const mode = artworkOf(id, slot).mode;
        return mode === "screenshot" || (mode === "" && showScreenshots);
    }
    function editArtwork(id) { dialogHost.artwork.openFor(id); }
    function openSettings(section) {
        settingsSection = section;
        navigate("settings");
        if (page === "settings" && pageLoader.item) pageLoader.item.section = section;
    }
    function showInstanceMenu(id, name, anchor) { dialogHost.instanceMenu.openFor(id, name, anchor); }
    function moveToGroup(id) { dialogHost.moveGroup.openFor(id); }
    function newGroup(instanceId) { dialogHost.groupName.openFor("", instanceId || ""); }
    function renameGroup(name) { dialogHost.groupName.openFor(name, ""); }
    function deleteGroup(name) {
        dialogHost.deleteGroup.group = name;
        dialogHost.deleteGroup.open();
    }
    // Prism reads groups only at startup, so an open Prism window needs a restart to show changes.
    function afterGroupEdit(message) {
        notify(instances.prismRunning() ? message + " · restart Prism to see it there" : message);
    }
    function createInstance() {
        dialogHost.newInstance.openFor("");
    }
    function instanceBusy(id) {
        if (session && session.instanceId === id && session.active && session.state !== "exited") {
            notify("Stop this instance before changing it.", true); return true;
        }
        if ((installer.instanceId === id && (installer.state === "resolving" || installer.state === "ready" || installer.state === "downloading")) ||
                (updater && updater.instanceId === id && updater.state === "updating")) {
            notify("Finish the content installation before changing this instance.", true); return true;
        }
        return false;
    }
    function duplicateInstance(id) { if (!instanceBusy(id)) dialogHost.duplicate.openFor(id); }
    function editVersions(id) { if (!instanceBusy(id)) dialogHost.newInstance.openFor(id); }
    property string pendingBrowseType: ""
    property string pendingBrowseWorld: ""
    function refresh() {
        selected = instances.count > 0 ? Math.max(0, Math.min(selected, instances.count - 1)) : -1;
        current = hasSelection ? instances.get(selected) : ({});
    }
    function preserveSelection(action) {
        const id = current.instanceId;
        action();
        for (let row = 0; row < instances.count; ++row) {
            if (instances.get(row).instanceId === id) {
                selected = row;
                break;
            }
        }
        refresh();
    }
    function reloadLibrary() {
        preserveSelection(function () {
            instances.reload();
        });
        if (page === "instance")
            details.refresh();
        notify("Library refreshed");
    }
    property string pendingBrowseQuery: ""
    function exportInstance(id) {
        dialogHost.exportPack.openFor(id);
    }
    function select(row) {
        if (!instances.count)
            return;
        selected = Math.max(0, Math.min(row, instances.count - 1));
        if (page === "library" && pageLoader.item)
            pageLoader.item.positionSelection(selected);
    }
    function selectId(id) {
        clearFilters();
        for (let row = 0; row < instances.count; ++row)
            if (instances.get(row).instanceId === id) {
                select(row);
                break;
            }
    }
    function openInstance(id, tab = "overview") {
        if (!instances.getById(id).instanceId)
            return;
        history.visit("instance", id, tab);
    }
    function clearFilters() {
        loaderFilter = "";
        searchText = "";
        if (page === "library" && pageLoader.item)
            pageLoader.item.clearSearch();
        instances.setFilter("", "");
    }
    function notify(message, error = false) {
        // Also written to the terminal/log, so problems can be traced afterwards.
        if (error) console.warn("Prismarine:", message); else console.info("Prismarine:", message);
        toast.show(message, error);
    }
    function applyPreferences() {
        Colors.userAccent = preferences.accentColor;
        Colors.theme = preferences.theme;
        Colors.cornerStyle = preferences.cornerStyle;
        Colors.overrides = preferences.paletteOverrides;
        Colors.systemMode = applicationTheme ? (applicationTheme.systemLight ? 1 : 2) : 0;
        Colors.animations = preferences.animations;
        Colors.decoFrames = preferences.decoFrames;
        instances.setPrismConsole(preferences.prismConsole);
        instances.setPrismProgram(preferences.prismProgram);
        preserveSelection(function () {
            instances.setSort(preferences.sortOrder);
        });
    }
    onSelectedChanged: refresh()
    onClosing: preferences.sync()
    Component.onCompleted: {
        page = preferences.startPage;
        applyPreferences();
        refresh();
    }
    onDebugDialogChanged: Qt.callLater(() => {
        if (debugDialog === "drop-overlay") dropOverlay.active = true;
        else dialogHost.openForLayoutCheck(debugDialog);
    })
    Timer {
        id: reefCrownTimer
        interval: 12000
        onTriggered: appWindow.reefCrownAwake = false
    }

    // Beneath the pages, so cards and rows with their own drop targets are asked first.
    DropArea {
        id: windowDrop
        anchors.fill: parent
        keys: ["text/uri-list"]
        enabled: !!appWindow.drops
        onEntered: drag => { if (!drag.hasUrls) drag.accepted = false; }
        onDropped: drop => {
            if (!drop.hasUrls) return;
            drop.acceptProposedAction();
            appWindow.handleDrop(drop.urls, "");
        }
    }
    PageDecor {
        anchors { fill: parent; leftMargin: 76 }
        // Only pages with open space: the waves must not run behind forms and lists.
        visible: Colors.decoFrames && ["session", "accounts", "friends"].indexOf(appWindow.page) >= 0
    }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        NavigationRail {
            controller: appWindow
            onNewInstanceRequested: dialogHost.newInstance.openFor("")
            onRevealCrownRequested: {
                appWindow.reefCrownAwake = true;
                reefCrownTimer.restart();
                appWindow.notify("A crown beneath the waves.");
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 0
        TopBar {
            controller: appWindow
        }
        PageStack {
            id: pageLoader
            objectName: "pageLoader"
            controller: appWindow
            backwards: history.backwards
            Layout.fillWidth: true
            Layout.fillHeight: true
        }
        ActivityBar {
            controller: appWindow
        }
        }
    }
    FirstRunScreen {
        id: firstRun
        anchors.fill: parent
        controller: appWindow
        visible: appWindow.showFirstRun
        onFinished: {
            appWindow.preferences.firstRunSeen = true;
            appWindow.showFirstRun = false;
        }
    }
    InstanceDragGhost { id: dragGhost; controller: appWindow }
    DropOverlay {
        id: dropOverlay
        active: windowDrop.containsDrag
        targetName: (appWindow.page === "instance" ? appWindow.instances.getById(appWindow.details.instanceId).name : appWindow.current.name) || ""
    }
    GamepadEditFrame {
        objectName: "gamepadEditFrame"
        target: appWindow.gamepadEditItem
        confirmLabel: appWindow.gamepad ? appWindow.gamepad.confirmLabel : "A"
        cancelLabel: appWindow.gamepad ? appWindow.gamepad.cancelLabel : "B"
    }
    LaunchActions { id: launchActions; controller: appWindow }
    readonly property alias launching: launchActions
    function play(id, name, force = false) { launchActions.play(id, name, force); }
    function launchAs(id, account) { launchActions.launchAs(id, account); }
    function abortLaunch() { launchActions.abortLaunch(); }
    function followLaunch(id) { launchActions.followLaunch(id); }
    function applyWhilePlaying() { launchActions.applyWhilePlaying(); }
    ContentActions { id: contentActions; controller: appWindow }
    readonly property var pageItem: pageLoader.item
    function importPack() { contentActions.importPack(); }
    function importDroppedPack(url) { contentActions.importDroppedPack(url); }
    function handleDrop(urls, targetId) { contentActions.handleDrop(urls, targetId); }
    function installPackVersion(version) { contentActions.installPackVersion(version); }
    function reviewSelection(id, type, world) { contentActions.reviewSelection(id, type, world); }
    function reviewInstall(id, version, type, world) { contentActions.reviewInstall(id, version, type, world); }
    function reviewLaunchFix(id, project) { return contentActions.reviewLaunchFix(id, project); }
    function browsePacks() { contentActions.browsePacks(); }
    function browseDatapacks(id, world) { contentActions.browseDatapacks(id, world); }
    function browseFor(id, text) { contentActions.browseFor(id, text); }
    AppShortcuts { controller: appWindow }
    SettingsIndex { id: settingsIndex }
    readonly property var settingsSections: settingsIndex.sections
    AppEvents { controller: appWindow }
    AppDialogs {
        id: dialogHost
        anchors.fill: parent
        controller: appWindow
    }
    Toast {
        id: toast
        availableWidth: appWindow.width
    }
}
