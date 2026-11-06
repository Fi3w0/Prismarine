import QtQuick

// Reacts to the application's services: errors become messages, and finished work refreshes pages.
Item {
    id: events
    required property var controller
    // The mod health check reruns only when the set of mod files changes.
    property string healthSignature: ""

    Connections {
        target: events.controller.instances
        function onAccountRequired() { events.controller.dialogs.accountNeeded.open(); }
        function onCountChanged() {
            const id = events.controller.current.instanceId;
            for (let row = 0; row < events.controller.instances.count; ++row)
                if (events.controller.instances.get(row).instanceId === id) {
                    events.controller.selected = row;
                    break;
                }
            events.controller.refresh();
        }
        function onErrorOccurred(message) {
            events.controller.notify(message, true);
        }
    }
    Connections {
        target: events.controller.applicationTheme
        function onSystemPaletteChanged() { Colors.systemMode = events.controller.applicationTheme.systemLight ? 1 : 2; }
    }
    Connections {
        target: events.controller.preferences
        function onChanged() {
            events.controller.applyPreferences();
        }
        function onErrorOccurred(message) {
            events.controller.notify(message, true);
        }
    }
    Connections {
        target: events.controller.details
        function onErrorOccurred(message) {
            events.controller.notify(message, true);
        }
    }
    Connections {
        target: events.controller.serverList
        ignoreUnknownSignals: true
        function onErrorOccurred(message) {
            events.controller.notify(message, true);
        }
    }
    Connections {
        target: events.controller.creator
        function onModified(id) {
            if (events.controller.details.instanceId === id) events.controller.details.refresh();
            if (events.controller.updater && events.controller.updater.instanceId === id) {
                events.controller.updater.cancel();
                events.controller.updater.check(id);
            }
        }
    }
    Connections {
        target: events.controller.updater
        ignoreUnknownSignals: true
        function onUpdated(id, count) {
            if (events.controller.details.instanceId === id)
                events.controller.details.refresh();
            events.controller.notify(count ? "Updated " + count + (count === 1 ? " file" : " files") : "No files were updated", !count);
        }
    }
    // Checking happens once per opened instance; the result feeds the overview and Mods tab.
    Connections {
        target: events.controller.details
        function onChanged() {
            const u = events.controller.updater, id = events.controller.details.instanceId;
            if (u && id && u.instanceId !== id && u.state !== "updating" && u.state !== "checking")
                u.check(id);
        }
    }
    Connections {
        target: events.controller.session
        ignoreUnknownSignals: true
        function onErrorOccurred(message) {
            events.controller.notify(message, true);
        }
        function onShared(url) {
            events.controller.notify("Log uploaded · link copied");
            Qt.openUrlExternally(url);
        }
    }
    Connections {
        target: events.controller.launchSettings
        function onErrorOccurred(message) {
            events.controller.notify(message, true);
        }
    }
    Connections {
        target: events.controller.accountManager
        function onErrorOccurred(message) {
            events.controller.notify(message, true);
        }
    }
    Connections {
        target: events.controller.installer
        function onInstalled(id, count) {
            if (events.controller.installingType) events.controller.downloads.clear(id, events.controller.installingType);
            if (events.controller.details.instanceId === id)
                events.controller.details.refresh();
            events.controller.notify(count + " files installed");
        }
    }
    Connections {
        target: events.controller.drops
        ignoreUnknownSignals: true
        function onInstalled(id, count) {
            if (events.controller.details.instanceId === id) events.controller.details.refresh();
        }
        function onErrorOccurred(message) { events.controller.notify(message, true); }
    }
    Connections {
        target: events.controller.details
        function onChanged() {
            const d = events.controller.details, h = events.controller.modHealth;
            if (!h || !d.instanceId || d.loading) return;
            const signature = d.instanceId + "|" + d.mods.map(it => it.fileName).join("|");
            if (signature === events.healthSignature) return;
            events.healthSignature = signature;
            h.check(d.instanceId);
        }
    }
    // The game's own log carries the launch screen from "Start Java" to the main menu.
    Connections {
        target: events.controller.session
        ignoreUnknownSignals: true
        function onChanged() {
            events.controller.applyWhilePlaying();
            const p = events.controller.launchProgress, s = events.controller.session;
            // An aborted launch whose game still appears is stopped right away.
            if (p && p.abortRequested && !events.controller.launching.gameRunningAtLaunch && s.instanceId === p.instanceId && s.processFound && s.state !== "exited") s.stop();
            if (!p || !p.active || s.instanceId !== p.instanceId || p.stage === "ready" || p.stage === "failed") return;
            if (s.state === "exited") p.reach("failed", "The game closed while starting. Now playing has the log and a crash check.");
            else if (s.menuReached) p.reach("ready", "In the main menu. Have fun!");
            else if (s.graphicsReady) p.reach("game", "Opening the game window");
            else if (s.processFound) p.reach("game", "Loading Minecraft and mods");
        }
    }
    // A launch that stopped before its game appeared leaves nothing for Now playing to show.
    Connections {
        target: events.controller.launchProgress
        ignoreUnknownSignals: true
        function onChanged() {
            const p = events.controller.launchProgress, s = events.controller.session;
            if (p && p.stage === "failed" && !p.abortRequested && s && s.instanceId === p.instanceId)
                events.controller.dialogs.launchOverlay.diagnosis = s.launchDiagnosis();
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
        onTriggered: if (events.controller.session && events.controller.session.state === "starting" && !events.controller.session.processFound) events.controller.session.dismiss()
    }
    Connections {
        target: events.controller.altLaunch
        ignoreUnknownSignals: true
        function onLaunched(altId, account) {
            events.controller.notify("Launching as " + account + " · multi-account copy");
            events.controller.followLaunch(altId);
        }
        function onErrorOccurred(message) { events.controller.notify(message, true); }
    }
    Connections {
        target: events.controller.desktop
        ignoreUnknownSignals: true
        function onErrorOccurred(message) { events.controller.notify(message, true); }
    }
    Connections {
        target: events.controller.network
        ignoreUnknownSignals: true
        function onErrorOccurred(message) { events.controller.notify(message, true); }
    }
    Connections {
        target: events.controller.storage
        ignoreUnknownSignals: true
        function onErrorOccurred(message) { events.controller.notify(message, true); }
    }
    Connections {
        target: events.controller.social
        function onErrorOccurred(message) { events.controller.notify(message, true); }
        function onNotice(message) { events.controller.notify(message); }
        function onJoinRequested(instanceId, address) {
            if (events.controller.instances.launchServer(instanceId, address)) events.controller.followLaunch(instanceId);
            else events.controller.notify("Could not join with this instance. Refresh the library and try again.", true);
        }
        function onPackReady(file) {
            if (events.controller.packImporter.state === "extracting" || events.controller.packImporter.state === "downloading") {
                events.controller.notify("Wait for the current import to finish.", true);
                return;
            }
            events.controller.packImporter.importFile(file);
            events.controller.dialogs.packImport.open();
        }
    }
    Connections {
        target: events.controller.packImporter
        function onImported(id) {
            events.controller.selectId(id);
            events.controller.openInstance(id);
            events.controller.notify("Pack imported");
        }
    }
    Connections {
        target: events.controller.packImporter
        function onHandedOff(format) {
            events.controller.notify(format + " pack opened in Prism's importer");
        }
    }
    Connections {
        target: events.controller.launcherMode
        function onInterfaceModeChanged() {
            const handheld = events.controller.launcherMode.interfaceMode === "handheld";
            events.controller.visibility = handheld ? Window.FullScreen : Window.Windowed;
            events.controller.notify(handheld ? "Handheld preview on. Choose Desktop or press F11 to leave full screen." : "Desktop interface on");
        }
    }
}
