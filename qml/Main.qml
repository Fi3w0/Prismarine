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
    property string page: preferences.startPage
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
    function openTab(tab) { openInstance(details.instanceId, tab); }
    function editSettings(id) {
        launchSettings.load(id);
        instanceSettings.open();
    }
    function renameInstance(id) { renameDialog.openFor(id); }
    RenameInstanceDialog { id: renameDialog; controller: appWindow; anchors.centerIn: Overlay.overlay }
    function importPack() {
        packImport.open();
    }
    function importDroppedPack(url) {
        if (packImporter.state === "extracting" || packImporter.state === "downloading" || packImporter.state === "fetching") {
            notify("Wait for the current import to finish.", true);
            return;
        }
        packImporter.importFile(url);
        packImport.open();
    }
    // Files dropped on the window or on one instance. A single modpack imports directly;
    // anything else is reviewed first.
    function handleDrop(urls, targetId) {
        if (!drops || !urls || !urls.length) return;
        const files = drops.inspect(urls);
        const packs = files.filter(it => it.kind === "modpack");
        if (files.length === 1 && packs.length === 1) {
            importDroppedPack(packs[0].url);
            return;
        }
        dropDialog.openFor(files, targetId || (page === "instance" ? details.instanceId : current.instanceId));
    }
    function saveModProfile() {
        const current = details.profiles.find(it => it.current);
        profilePrompt.ask(current ? current.name : "");
    }
    property bool multiAccountAccepted: false
    function launchAs(id, account) {
        if (!altLaunch || !preferences.multiAccount) return;
        if (!multiAccountAccepted) {
            multiAccountWarning.instanceId = id;
            multiAccountWarning.account = account;
            multiAccountWarning.open();
            return;
        }
        if (altLaunch.launchAs(id, account)) notify("Preparing a copy for " + account + "…");
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
    // Settings sections with search words, shared by the Settings sidebar and Ctrl+K.
    readonly property var settingsSections: [
        { group: "Prismarine", name: "Interface", words: "theme accent colour color dark light system animations frames start page" },
        { group: "Prismarine", name: "Library & covers", words: "covers rows list sort screenshots sidebar view" },
        { group: "Launcher", name: "Java & game", words: "java memory ram jvm arguments runtime temurin wrapper launch command" },
        { group: "Launcher", name: "Network", words: "proxy socks http downloads parallel timeout retries token modrinth curseforge key user agent metadata mirror" },
        { group: "Launcher", name: "Storage", words: "disk space clean cleanup logs cache worlds trash shared duplicates hard links" },
        { group: "Launcher", name: "Accounts", words: "account skin cape microsoft profile sign in" },
        { group: "Other", name: "Experimental", words: "multi-account alt accounts unsafe" },
        { group: "Other", name: "About", words: "version licence license credits" }
    ]
    function openPalette() { commandPalette.openPalette(); }
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
    function editArtwork(id) { artworkDialog.openFor(id); }
    function openSettings(section) {
        settingsSection = section;
        navigate("settings");
        if (page === "settings" && pageLoader.item) pageLoader.item.section = section;
    }
    function showInstanceMenu(id, name) { instanceMenu.openFor(id, name); }
    function moveToGroup(id) { moveGroupDialog.openFor(id); }
    function newGroup(instanceId) { groupNameDialog.openFor("", instanceId || ""); }
    function renameGroup(name) { groupNameDialog.openFor(name, ""); }
    function deleteGroup(name) {
        deleteGroupConfirm.group = name;
        deleteGroupConfirm.open();
    }
    // Prism reads groups only at startup, so an open Prism window needs a restart to show changes.
    function afterGroupEdit(message) {
        notify(instances.prismRunning() ? message + " · restart Prism to see it there" : message);
    }
    function createInstance() {
        newInstance.openFor("");
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
    function duplicateInstance(id) { if (!instanceBusy(id)) duplicateDialog.openFor(id); }
    function editVersions(id) { if (!instanceBusy(id)) newInstance.openFor(id); }
    function browsePacks() {
        if (page === "browse" && pageLoader.item) {
            pageLoader.item.chooseType("modpack");
        } else {
            pendingBrowseType = "modpack";
            navigate("browse");
        }
    }
    property string pendingBrowseType: ""
    DuplicateDialog { id: duplicateDialog; controller: appWindow; anchors.centerIn: Overlay.overlay }
    property string pendingBrowseWorld: ""
    function installPackVersion(version) { packImporter.importVersion(version); packImport.open(); }
    function browseDatapacks(id, world) { details.load(id); pendingBrowseType = "datapack"; pendingBrowseWorld = world; navigate("browse"); }
    function reviewSelection(id, type, world) {
        installingType = type;
        installer.prepareMany(id, downloads.items(id, type).map(it => it.version), type, world || "");
        installReview.open();
    }
    function reviewInstall(id, version, type) {
        installer.prepare(id, version, type);
        installReview.open();
    }
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
    // Known mod errors (from the last health check of this instance) ask before launching.
    function play(id, name, force = false) {
        if (!force && modHealth && modHealth.instanceId === id && !modHealth.checking && modHealth.errors > 0) {
            launchWarning.instanceId = id;
            launchWarning.name = name;
            launchWarning.open();
            return;
        }
        // Prism can run an instance only once; offer the useful choices instead.
        if (id && instances.isRunning(id)) {
            alreadyRunning.instanceId = id;
            alreadyRunning.name = name;
            alreadyRunning.open();
            return;
        }
        if (!id || !instances.launch(id))
            return;
        notify("Launching " + name + "…");
        followLaunch(id);
    }
    // Opens Browse for an instance with a search already typed, e.g. a missing dependency.
    property string pendingBrowseQuery: ""
    function browseFor(id, text) {
        if (id && details.instanceId !== id)
            details.load(id);
        pendingBrowseQuery = text;
        navigate("browse");
    }
    function exportInstance(id) {
        exportDialog.openFor(id);
    }
    // Stops the launch shown on the launch screen: the game if it is already running,
    // otherwise the Prism process started for it (see LaunchProgress::abort).
    // Set when a launch starts; Abort never stops a game that was already running then.
    property bool gameRunningAtLaunch: false
    function abortLaunch() {
        if (!launchProgress || !launchProgress.active) return;
        if (!gameRunningAtLaunch && session && session.instanceId === launchProgress.instanceId && session.processFound && session.state !== "exited")
            session.stop();
        launchProgress.abort();
        notify("Launch aborted");
    }
    function followLaunch(id) {
        gameRunningAtLaunch = instances.isRunning(id);
        if (launchProgress) {
            launchProgress.start(id);
            launchOverlay.open();
        }
        if (session && session.start(id))
            navigate("session");
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
        applyPreferences();
        refresh();
    }
    Connections {
        target: appWindow.instances
        function onCountChanged() {
            const id = appWindow.current.instanceId;
            for (let row = 0; row < appWindow.instances.count; ++row)
                if (appWindow.instances.get(row).instanceId === id) {
                    appWindow.selected = row;
                    break;
                }
            appWindow.refresh();
        }
        function onErrorOccurred(message) {
            appWindow.notify(message, true);
        }
    }
    Connections {
        target: appWindow.preferences
        function onChanged() {
            appWindow.applyPreferences();
        }
        function onErrorOccurred(message) {
            appWindow.notify(message, true);
        }
    }
    Connections {
        target: appWindow.details
        function onErrorOccurred(message) {
            appWindow.notify(message, true);
        }
    }
    Connections {
        target: appWindow.serverList
        ignoreUnknownSignals: true
        function onErrorOccurred(message) {
            appWindow.notify(message, true);
        }
    }
    Connections {
        target: appWindow.creator
        function onModified(id) {
            if (appWindow.details.instanceId === id) appWindow.details.refresh();
            if (appWindow.updater && appWindow.updater.instanceId === id) {
                appWindow.updater.cancel();
                appWindow.updater.check(id);
            }
        }
    }
    Connections {
        target: appWindow.updater
        ignoreUnknownSignals: true
        function onUpdated(id, count) {
            if (appWindow.details.instanceId === id)
                appWindow.details.refresh();
            appWindow.notify(count ? "Updated " + count + (count === 1 ? " file" : " files") : "No files were updated", !count);
        }
    }
    // Checking happens once per opened instance; the result feeds the overview and Mods tab.
    Connections {
        target: appWindow.details
        function onChanged() {
            const u = appWindow.updater, id = appWindow.details.instanceId;
            if (u && id && u.instanceId !== id && u.state !== "updating" && u.state !== "checking")
                u.check(id);
        }
    }
    Connections {
        target: appWindow.session
        ignoreUnknownSignals: true
        function onErrorOccurred(message) {
            appWindow.notify(message, true);
        }
        function onShared(url) {
            appWindow.notify("Log uploaded · link copied");
            Qt.openUrlExternally(url);
        }
    }
    Connections {
        target: appWindow.launchSettings
        function onErrorOccurred(message) {
            appWindow.notify(message, true);
        }
    }
    Connections {
        target: appWindow.accountManager
        function onErrorOccurred(message) {
            appWindow.notify(message, true);
        }
    }
    Connections {
        target: appWindow.installer
        function onInstalled(id, count) {
            appWindow.downloads.clear(id, appWindow.installingType);
            if (appWindow.details.instanceId === id)
                appWindow.details.refresh();
            appWindow.notify(count + " files installed");
        }
    }
    Connections {
        target: appWindow.drops
        ignoreUnknownSignals: true
        function onInstalled(id, count) {
            if (appWindow.details.instanceId === id) appWindow.details.refresh();
        }
        function onErrorOccurred(message) { appWindow.notify(message, true); }
    }
    // The health check reruns only when the set of mod files changes.
    property string healthSignature: ""
    Connections {
        target: appWindow.details
        function onChanged() {
            const d = appWindow.details, h = appWindow.modHealth;
            if (!h || !d.instanceId || d.loading) return;
            const signature = d.instanceId + "|" + d.mods.map(it => it.fileName).join("|");
            if (signature === appWindow.healthSignature) return;
            appWindow.healthSignature = signature;
            h.check(d.instanceId);
        }
    }
    // "While playing": minimize or hide this window once the game window is up,
    // and bring it back when the game closes.
    property string awayForGame: ""
    function applyWhilePlaying() {
        const s = session;
        if (!s || !s.active) return;
        if (s.state === "exited") {
            if (awayForGame) {
                const wasHidden = awayForGame === "hide";
                awayForGame = "";
                if (wasHidden) show();
                showNormal();
                raise();
                requestActivate();
            }
            return;
        }
        if (awayForGame || !(s.graphicsReady || s.menuReached)) return;
        const info = instances.getById(s.instanceId).instanceId ? instances.getById(s.instanceId) : (instances.copies().find(it => it.instanceId === s.instanceId) || {});
        let mode = preferences.whilePlayingFor(info.altOf || s.instanceId);
        // Hiding needs reliable exit detection, or the window could not come back.
        if (mode === "hide" && !s.tracksProcess) mode = "minimize";
        if (mode === "keep") return;
        awayForGame = mode;
        if (mode === "hide") hide(); else showMinimized();
    }
    // The game's own log carries the launch screen from "Start Java" to the main menu.
    Connections {
        target: appWindow.session
        ignoreUnknownSignals: true
        function onChanged() {
            appWindow.applyWhilePlaying();
            const p = appWindow.launchProgress, s = appWindow.session;
            // An aborted launch whose game still appears is stopped right away.
            if (p && p.abortRequested && !appWindow.gameRunningAtLaunch && s.instanceId === p.instanceId && s.processFound && s.state !== "exited") s.stop();
            if (!p || !p.active || s.instanceId !== p.instanceId || p.stage === "ready" || p.stage === "failed") return;
            if (s.state === "exited") p.reach("failed", "The game closed while starting. Now playing has the log and a crash check.");
            else if (s.menuReached) p.reach("ready", "In the main menu. Have fun!");
            else if (s.graphicsReady) p.reach("game", "Opening the game window");
            else if (s.processFound) p.reach("game", "Loading Minecraft and mods");
        }
    }
    // A launch that stopped before its game appeared leaves nothing for Now playing to show.
    Connections {
        target: appWindow.launchProgress
        ignoreUnknownSignals: true
        function onChanged() {
            const p = appWindow.launchProgress, s = appWindow.session;
            if (!p || p.stage !== "failed" || !s || s.instanceId !== p.instanceId || s.processFound || s.state !== "starting") return;
            // A Prism that was already open may still start the game after an abort; the game is
            // stopped when it appears, so wait a while before giving up on it.
            if (p.abortRequested && p.prismWasRunning) abandonedLaunch.restart();
            else s.dismiss();
        }
    }
    Timer {
        id: abandonedLaunch
        interval: 90000
        onTriggered: if (appWindow.session && appWindow.session.state === "starting" && !appWindow.session.processFound) appWindow.session.dismiss()
    }
    Connections {
        target: appWindow.altLaunch
        ignoreUnknownSignals: true
        function onLaunched(altId, account) {
            appWindow.notify("Launching as " + account + " · multi-account copy");
            appWindow.followLaunch(altId);
        }
        function onErrorOccurred(message) { appWindow.notify(message, true); }
    }
    Connections {
        target: appWindow.desktop
        ignoreUnknownSignals: true
        function onErrorOccurred(message) { appWindow.notify(message, true); }
    }
    Connections {
        target: appWindow.network
        ignoreUnknownSignals: true
        function onErrorOccurred(message) { appWindow.notify(message, true); }
    }
    Connections {
        target: appWindow.storage
        ignoreUnknownSignals: true
        function onErrorOccurred(message) { appWindow.notify(message, true); }
    }
    onDebugDialogChanged: Qt.callLater(function() {
        const id = current.instanceId || (instances.allInstances[0] || {}).instanceId || "";
        switch (debugDialog) {
        case "new-instance": createInstance(); break;
        case "versions": editVersions(id); break;
        case "import": importPack(); break;
        case "rename": renameInstance(id); break;
        case "duplicate": duplicateInstance(id); break;
        case "export": exportInstance(id); break;
        case "settings": editSettings(id); break;
        case "group": newGroup(""); break;
        case "move-group": moveToGroup(id); break;
        case "delete-group": deleteGroup(instances.groupNames()[0] || "Group"); break;
        case "menu": instanceMenu.x = 300; instanceMenu.y = 200; instanceMenu.instanceId = id; instanceMenu.open(); break;
        case "drop":
            dropDialog.openFor([
                { url: "file:///tmp/sodium-fabric-0.6.0.jar", fileName: "sodium-fabric-0.6.0.jar", name: "Sodium", kind: "mod", loaders: ["Fabric"] },
                { url: "file:///tmp/create-1.21.1.jar", fileName: "create-1.21.1-6.0.jar", name: "Create", kind: "mod", loaders: ["NeoForge"] },
                { url: "file:///tmp/Faithful.zip", fileName: "Faithful 32x.zip", name: "Faithful 32x", kind: "resourcepack", loaders: [] },
                { url: "file:///tmp/BSL.zip", fileName: "BSL_v8.4.zip", name: "BSL_v8.4", kind: "shader", loaders: [] },
                { url: "file:///tmp/pack.mrpack", fileName: "Fabulously Optimized.mrpack", name: "Fabulously Optimized", kind: "modpack", loaders: [] },
                { url: "file:///tmp/notes.zip", fileName: "notes.zip", name: "notes", kind: "unknown", loaders: [] }
            ], id); break;
        case "drop-overlay": dropOverlay.active = true; break;
        case "palette": openPalette(); break;
        case "artwork": editArtwork(id); break;
        case "launch":
            if (launchProgress) { launchProgress.start(id); launchProgress.reach("signin", "Getting authorization to access Mojang services"); launchOverlay.open(); }
            break;
        case "profile": saveModProfile(); break;
        case "multi-account": launchAs(id, (instances.accounts[0] || {}).name || "Steve"); break;
        }
    })
    Shortcut {
        sequences: ["Ctrl+K", "Ctrl+Shift+P"]
        onActivated: appWindow.openPalette()
    }
    Shortcut {
        sequence: "Ctrl+F"
        onActivated: {
            appWindow.navigate("library");
            if (pageLoader.item)
                pageLoader.item.focusSearch();
        }
    }
    Shortcut {
        sequence: "F2"
        enabled: !renameDialog.visible && ((appWindow.page === "library" && appWindow.hasSelection) || (appWindow.page === "instance" && !!appWindow.details.instanceId))
        onActivated: appWindow.renameInstance(appWindow.page === "instance" ? appWindow.details.instanceId : appWindow.current.instanceId)
    }
    Shortcut {
        sequence: "Ctrl+R"
        onActivated: appWindow.reloadLibrary()
    }
    Shortcut {
        sequence: "F5"
        onActivated: appWindow.reloadLibrary()
    }
    Shortcut {
        sequence: "Alt+Left"
        onActivated: appWindow.back()
    }
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
    RowLayout {
        anchors.fill: parent
        spacing: 0
        NavigationRail {
            controller: appWindow
            onNewInstanceRequested: newInstance.openFor("")
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
        MotionLoader {
            backwards: history.backwards
            id: pageLoader
            objectName: "pageLoader"
            Layout.fillWidth: true
            Layout.fillHeight: true
            sourceComponent: appWindow.page === "home" ? homePage : appWindow.page === "instance" ? instancePage : appWindow.page === "settings" ? settingsPage : appWindow.page === "accounts" ? accountsPage : appWindow.page === "friends" ? friendsPage : appWindow.page === "browse" ? browsePage : appWindow.page === "session" && appWindow.session ? sessionPage : libraryPage
            opacity: 1
        }
        ActivityBar {
            controller: appWindow
        }
        }
    }
    Component {
        id: libraryPage
        LibraryPage {
            controller: appWindow
        }
    }
    Component {
        id: homePage
        HomePage {
            controller: appWindow
        }
    }
    Component {
        id: instancePage
        InstancePage {
            controller: appWindow
        }
    }
    Component {
        id: settingsPage
        SettingsPage {
            controller: appWindow
        }
    }
    Component {
        id: friendsPage
        FriendsPage { controller: appWindow }
    }
    Component {
        id: accountsPage
        AccountsPage {
            controller: appWindow
        }
    }
    Component {
        id: sessionPage
        SessionPage {
            controller: appWindow
            tab: appWindow.sessionTab
        }
    }
    Component {
        id: browsePage
        BrowsePage {
            controller: appWindow
        }
    }

    Connections {
        target: appWindow.social
        function onErrorOccurred(message) { appWindow.notify(message, true); }
        function onNotice(message) { appWindow.notify(message); }
        function onJoinRequested(instanceId, address) {
            if (appWindow.instances.launchServer(instanceId, address)) appWindow.followLaunch(instanceId);
            else appWindow.notify("Could not join with this instance. Refresh the library and try again.", true);
        }
        function onPackReady(file) {
            if (appWindow.packImporter.state === "extracting" || appWindow.packImporter.state === "downloading") {
                appWindow.notify("Wait for the current import to finish.", true);
                return;
            }
            appWindow.packImporter.importFile(file);
            packImport.open();
        }
    }

    NewInstanceDialog {
        id: newInstance
        controller: appWindow
        anchors.centerIn: parent
    }

    InstanceSettingsDialog {
        id: instanceSettings
        controller: appWindow
        anchors.centerIn: parent
    }
    InstallReviewDialog {
        id: installReview
        controller: appWindow
        anchors.centerIn: parent
    }
    Connections {
        target: appWindow.packImporter
        function onImported(id) {
            appWindow.selectId(id);
            appWindow.openInstance(id);
            appWindow.notify("Pack imported");
        }
    }
    Connections {
        target: appWindow.packImporter
        function onHandedOff(format) {
            appWindow.notify(format + " pack opened in Prism's importer");
        }
    }
    ExportDialog {
        id: exportDialog
        controller: appWindow
        anchors.centerIn: parent
    }
    PackImportDialog {
        id: packImport
        controller: appWindow
        anchors.centerIn: parent
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
    Rectangle {
        id: dragGhost
        objectName: "instanceDragGhost"
        z: 1000
        visible: !!appWindow.draggingId
        width: Math.min(280, ghostLabel.implicitWidth + 44)
        height: 34
        radius: 9
        color: Colors.surfaceHi
        border.color: Colors.accent
        Drag.active: !!appWindow.draggingId
        Drag.keys: ["prismarine/instance"]
        Drag.hotSpot.x: 14
        Drag.hotSpot.y: height / 2
        Row {
            anchors { fill: parent; leftMargin: 12; rightMargin: 12 }
            spacing: 8
            LineIcon { name: "folder"; tint: Colors.accent; width: 16; height: 16; anchors.verticalCenter: parent.verticalCenter }
            Text {
                id: ghostLabel
                anchors.verticalCenter: parent.verticalCenter
                width: Math.min(implicitWidth, 220)
                text: appWindow.draggingName
                color: Colors.text
                font.pixelSize: 13
                elide: Text.ElideRight
            }
        }
    }
    DropOverlay {
        id: dropOverlay
        active: windowDrop.containsDrag
        targetName: (appWindow.page === "instance" ? appWindow.instances.getById(appWindow.details.instanceId).name : appWindow.current.name) || ""
    }
    ConfirmDialog {
        id: alreadyRunning
        objectName: "alreadyRunning"
        property string instanceId: ""
        property string name: ""
        anchors.centerIn: Overlay.overlay
        title: name + " is already running"
        message: "Prism can run each instance only once. To play it with a second account at the same time, use the ▾ next to Play on the instance page"
            + (appWindow.preferences.multiAccount ? "." : " after turning on Settings → Experimental → Multi-account play.")
        confirmText: "Go to Now playing"
        onConfirmed: {
            if (appWindow.session) appWindow.session.start(instanceId);
            appWindow.navigate("session");
        }
    }
    ConfirmDialog {
        id: launchWarning
        objectName: "launchWarning"
        property string instanceId: ""
        property string name: ""
        anchors.centerIn: Overlay.overlay
        title: "Launch with mod errors?"
        message: (appWindow.modHealth ? appWindow.modHealth.errors : 0) + " problems were found in this instance's mods, such as duplicates or missing dependencies. The game will probably stop while loading. Fix them in the Mods tab, or launch anyway."
        confirmText: "Launch anyway"
        danger: true
        onConfirmed: appWindow.play(instanceId, name, true)
    }
    ConfirmDialog {
        id: multiAccountWarning
        objectName: "multiAccountWarning"
        property string instanceId: ""
        property string account: ""
        anchors.centerIn: Overlay.overlay
        width: 520
        title: "Play as " + account + "? (unsafe)"
        message: "Prism runs one game per instance, so Prismarine makes a separate copy for " + account + " and refreshes it from the original before every launch. "
            + "Mods and packs are shared as hard links, config is copied over the copy's own each time, and worlds are never shared. "
            + "The original is only read, but two games at once double memory use, and a mod that writes into its own jar would affect both. Use at your own risk."
        confirmText: "I understand, launch"
        danger: true
        onConfirmed: {
            appWindow.multiAccountAccepted = true;
            appWindow.launchAs(instanceId, account);
        }
    }
    TextPromptDialog {
        id: profilePrompt
        objectName: "profilePrompt"
        anchors.centerIn: Overlay.overlay
        title: "Save mod profile"
        subtitle: "Remembers which mods are on and off. Saving under an existing name replaces it."
        placeholder: "Profile name, e.g. Performance"
        confirmText: "Save"
        Connections {
            target: appWindow.details
            function onErrorOccurred(message) { if (profilePrompt.visible) profilePrompt.error = message; }
        }
        onSubmitted: value => {
            if (!appWindow.details.saveProfile(value)) return;
            close();
            appWindow.notify("Profile saved");
        }
    }
    DropInstallDialog { id: dropDialog; controller: appWindow; anchors.centerIn: Overlay.overlay }
    GroupNameDialog { id: groupNameDialog; controller: appWindow; anchors.centerIn: Overlay.overlay }
    MoveToGroupDialog { id: moveGroupDialog; controller: appWindow; anchors.centerIn: Overlay.overlay }
    InstanceContextMenu { id: instanceMenu; controller: appWindow }
    CommandPalette { id: commandPalette; controller: appWindow }
    LaunchOverlay { id: launchOverlay; controller: appWindow }
    ArtworkDialog { id: artworkDialog; controller: appWindow; anchors.centerIn: Overlay.overlay }
    ConfirmDialog {
        id: deleteGroupConfirm
        property string group: ""
        anchors.centerIn: Overlay.overlay
        title: "Delete “" + group + "”?"
        message: "Its instances move to Ungrouped. No instance or file is deleted."
        confirmText: "Delete group"
        danger: true
        onConfirmed: if (appWindow.instances.deleteGroup(group)) appWindow.afterGroupEdit("Group deleted")
    }
    Toast {
        id: toast
        availableWidth: appWindow.width
    }
}
