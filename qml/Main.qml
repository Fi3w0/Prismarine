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
    function importPack() {
        dialogHost.packImport.open();
    }
    function importDroppedPack(url) {
        if (packImporter.state === "extracting" || packImporter.state === "downloading" || packImporter.state === "fetching") {
            notify("Wait for the current import to finish.", true);
            return;
        }
        packImporter.importFile(url);
        dialogHost.packImport.open();
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
        dialogHost.drop.openFor(files, targetId || (page === "instance" ? details.instanceId : current.instanceId));
    }
    function saveModProfile() {
        const current = details.profiles.find(it => it.current);
        dialogHost.profilePrompt.ask(current ? current.name : "");
    }
    property bool multiAccountAccepted: false
    function launchAs(id, account) {
        if (!altLaunch || !preferences.multiAccount) return;
        if (!multiAccountAccepted) {
            dialogHost.multiAccountWarning.instanceId = id;
            dialogHost.multiAccountWarning.account = account;
            dialogHost.multiAccountWarning.open();
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
        { group: "Prismarine", name: "Interface", words: "friends hide tab scroll speed wheel mouse theme accent colour color dark light system animations motion size scale start page home sections background palette surfaces rail text contrast hue hsv hex while playing minimize hide console" },
        { group: "Prismarine", name: "Library & covers", words: "covers rows list sort screenshots sidebar view density frames cover size badges" },
        { group: "Launcher", name: "Launcher mode", words: "full stable mode engine update remove delete uninstall prism handheld shortcuts" },
        { group: "Launcher", name: "Prism integration", words: "classic prism progress desktop window rule program executable" },
        { group: "Launcher", name: "Java & game", words: "java memory ram jvm arguments runtime temurin wrapper launch command" },
        { group: "Launcher", name: "Network", words: "proxy socks http downloads parallel timeout retries token modrinth curseforge key user agent metadata mirror" },
        { group: "Launcher", name: "Storage", words: "disk space clean cleanup logs cache worlds trash shared duplicates hard links" },
        { group: "Launcher", name: "Accounts", words: "account skin cape microsoft profile sign in" },
        { group: "Other", name: "Experimental", words: "multi-account alt accounts unsafe" },
        { group: "Other", name: "About", words: "version licence license credits" }
    ]
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
    function browsePacks() {
        if (page === "browse" && pageLoader.item) {
            pageLoader.item.chooseType("modpack");
        } else {
            pendingBrowseType = "modpack";
            navigate("browse");
        }
    }
    property string pendingBrowseType: ""
    property string pendingBrowseWorld: ""
    function installPackVersion(version) { packImporter.importVersion(version); dialogHost.packImport.open(); }
    function browseDatapacks(id, world) { details.load(id); pendingBrowseType = "datapack"; pendingBrowseWorld = world; navigate("browse"); }
    function reviewSelection(id, type, world) {
        dialogHost.installReview.retryInstanceId = "";
        installingType = type;
        installer.prepareMany(id, downloads.items(id, type).map(it => it.version), type, world || "");
        dialogHost.installReview.open();
    }
    function reviewInstall(id, version, type, world) {
        if (instanceBusy(id)) return;
        dialogHost.installReview.retryInstanceId = "";
        installingType = "";
        installer.prepare(id, version, type, world || "");
        dialogHost.installReview.open();
    }
    function reviewLaunchFix(id, project) {
        if (instanceBusy(id)) return false;
        if (instances.isRunning(id) || ["resolving", "ready", "downloading"].indexOf(installer.state) >= 0) {
            notify("Stop the game and finish any content installation before installing a fix.", true);
            return false;
        }
        // A repair does not consume the user's separate Browse selection.
        installingType = "";
        dialogHost.installReview.retryInstanceId = id;
        dialogHost.installReview.repairProject = project;
        dialogHost.installReview.repairDetail = dialogHost.launchOverlay.finding.detail || "";
        installer.prepareProject(id, project);
        dialogHost.installReview.open();
        return true;
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
            dialogHost.launchWarning.instanceId = id;
            dialogHost.launchWarning.name = name;
            dialogHost.launchWarning.open();
            return;
        }
        // Prism can run an instance only once; offer the useful choices instead.
        if (id && instances.isRunning(id)) {
            dialogHost.alreadyRunning.instanceId = id;
            dialogHost.alreadyRunning.name = name;
            dialogHost.alreadyRunning.open();
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
        dialogHost.exportPack.openFor(id);
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
            dialogHost.launchOverlay.open();
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
        case "menu": dialogHost.instanceMenu.x = 300; dialogHost.instanceMenu.y = 200; dialogHost.instanceMenu.instanceId = id; dialogHost.instanceMenu.open(); break;
        case "drop":
            dialogHost.drop.openFor([
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
            if (launchProgress) { launchProgress.start(id); launchProgress.reach("signin", "Getting authorization to access Mojang services"); dialogHost.launchOverlay.open(); }
            break;
        case "profile": saveModProfile(); break;
        case "multi-account": launchAs(id, (instances.accounts[0] || {}).name || "Steve"); break;
        }
    })
    Shortcut {
        sequence: "F11"
        onActivated: appWindow.visibility = appWindow.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
    }
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
        enabled: !dialogHost.rename.visible && ((appWindow.page === "library" && appWindow.hasSelection) || (appWindow.page === "instance" && !!appWindow.details.instanceId))
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
                font.pixelSize: Typography.body
                elide: Text.ElideRight
            }
        }
    }
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
