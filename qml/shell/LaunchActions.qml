import QtQuick

// Starting and stopping games, and what the window does while one runs.
QtObject {
    required property var controller
    property bool multiAccountAccepted: false
    // Set when a launch starts; Abort never stops a game that was already running then.
    property bool gameRunningAtLaunch: false
    // What "While playing" did to the window, so it can come back when the game closes.
    property string awayForGame: ""

    // Known mod errors (from the last health check of this instance) ask before launching.
    function play(id, name, force = false) {
        if (!force && controller.modHealth && controller.modHealth.instanceId === id && !controller.modHealth.checking && controller.modHealth.errors > 0) {
            controller.dialogs.launchWarning.instanceId = id;
            controller.dialogs.launchWarning.name = name;
            controller.dialogs.launchWarning.open();
            return;
        }
        // Prism can run an instance only once; offer the useful choices instead.
        if (id && controller.instances.isRunning(id)) {
            controller.dialogs.alreadyRunning.instanceId = id;
            controller.dialogs.alreadyRunning.name = name;
            controller.dialogs.alreadyRunning.open();
            return;
        }
        if (!id || !controller.instances.launch(id))
            return;
        controller.notify("Launching " + name + "…");
        followLaunch(id);
    }
    function launchAs(id, account) {
        if (!controller.altLaunch || !controller.preferences.multiAccount) return;
        if (!multiAccountAccepted) {
            controller.dialogs.multiAccountWarning.instanceId = id;
            controller.dialogs.multiAccountWarning.account = account;
            controller.dialogs.multiAccountWarning.open();
            return;
        }
        if (controller.altLaunch.launchAs(id, account)) controller.notify("Preparing a copy for " + account + "…");
    }
    function abortLaunch() {
        if (!controller.launchProgress || !controller.launchProgress.active) return;
        if (!gameRunningAtLaunch && controller.session && controller.session.instanceId === controller.launchProgress.instanceId && controller.session.processFound && controller.session.state !== "exited")
            controller.session.stop();
        controller.launchProgress.abort();
        controller.notify("Launch aborted");
    }
    function followLaunch(id) {
        gameRunningAtLaunch = controller.instances.isRunning(id);
        if (controller.launchProgress) {
            controller.launchProgress.start(id);
            controller.dialogs.launchOverlay.open();
        }
        if (controller.session && controller.session.start(id))
            controller.navigate("session");
    }
    function applyWhilePlaying() {
        const s = controller.session;
        if (!s || !s.active) return;
        if (s.state === "exited") {
            if (awayForGame) {
                const wasHidden = awayForGame === "hide";
                awayForGame = "";
                if (wasHidden) controller.show();
                controller.showNormal();
                controller.raise();
                controller.requestActivate();
            }
            return;
        }
        if (awayForGame || !(s.graphicsReady || s.menuReached)) return;
        const info = controller.instances.getById(s.instanceId).instanceId ? controller.instances.getById(s.instanceId) : (controller.instances.copies().find(it => it.instanceId === s.instanceId) || {});
        let mode = controller.preferences.whilePlayingFor(info.altOf || s.instanceId);
        // Hiding needs reliable exit detection, or the window could not come back.
        if (mode === "hide" && !s.tracksProcess) mode = "minimize";
        if (mode === "keep") return;
        awayForGame = mode;
        if (mode === "hide") controller.hide(); else controller.showMinimized();
    }
}
