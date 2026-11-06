import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Now playing": one tab per running game (its steps, memory and live log) and an
// "All games" tab with the machine's CPU, memory and GPU load.
Item {
    id: screen
    required property var controller
    // "all", an instance id, or "" to follow the game Prismarine launched last.
    property string tab: ""
    readonly property var running: controller.games ? controller.games.games : []
    readonly property string current: tab !== "" ? tab : controller.session.active ? controller.session.instanceId : running.length ? running[0].instanceId : ""
    readonly property bool hardware: current === "all"
    readonly property var session: {
        running; // re-evaluate when games come and go
        const followed = !hardware && current && controller.games ? controller.games.sessionFor(current) : null;
        return followed || controller.session;
    }
    readonly property var info: controller.instances.getById(session.instanceId).instanceId ? controller.instances.getById(session.instanceId)
        : controller.instances.copies().find(it => it.instanceId === session.instanceId) || ({})
    readonly property bool exited: session.state === "exited"
    // The monitor's figures for the shown game: CPU share and its history.
    readonly property var stats: running.find(it => it.instanceId === session.instanceId) || null
    objectName: "sessionPage"

    function clock(secs) {
        const pad = n => (n < 10 ? "0" : "") + n;
        return Math.floor(secs / 3600) + ":" + pad(Math.floor(secs / 60) % 60) + ":" + pad(secs % 60);
    }

    // A forgotten game's tab falls back to the launched one.
    onRunningChanged: if (tab !== "" && tab !== "all" && !running.some(it => it.instanceId === tab) && controller.session.instanceId !== tab) tab = ""

    RowLayout {
        id: tabs
        objectName: "sessionTabs"
        visible: !!screen.controller.games && (screen.running.length > 0 || screen.hardware)
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20; bottomMargin: 0 }
        height: visible ? 40 : 0
        spacing: 8
        SessionTab {
            page: screen
            objectName: "allGamesTab"
            key: "all"
            label: "All games"
            sub: screen.controller.games ? Math.round(screen.controller.games.system.cpuPercent || 0) + "% CPU" : ""
        }
        Repeater {
            model: screen.running
            delegate: SessionTab {
                required property var modelData
                page: screen
                key: modelData.instanceId
                label: modelData.name + (modelData.account ? " · " + modelData.account : "")
                sub: modelData.memoryMiB ? (modelData.memoryMiB / 1024).toFixed(1) + " GiB" : ""
                live: modelData.state !== "exited"
                closable: !live
                onCloseRequested: screen.controller.games.forget(modelData.instanceId)
            }
        }
        Item { Layout.fillWidth: true }
    }

    HardwareView {
        visible: screen.hardware
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: tabs.bottom; margins: 20; topMargin: 14 }
        controller: screen.controller
        onOpenGame: id => screen.tab = id
    }

    SessionEmptyState {
        page: screen
        anchors.centerIn: parent
        width: Math.min(560, parent.width - 64)
        visible: !screen.session.active && !screen.hardware
    }
    ColumnLayout {
        visible: screen.session.active && !screen.hardware
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: tabs.bottom; margins: 20; topMargin: tabs.visible ? 14 : 0 }
        spacing: 18
        SessionHeader {
            page: screen
            Layout.fillWidth: true
            onStopRequested: stopConfirm.open()
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18
            SessionSidePanel { page: screen }
            LiveLog {
                Layout.fillWidth: true
                Layout.fillHeight: true
                controller: screen.controller
                session: screen.session
                onShareRequested: shareConfirm.open()
            }
        }
    }
    ConfirmDialog {
        id: stopConfirm
        anchors.centerIn: parent
        title: "Stop " + screen.session.name + "?"
        message: "Minecraft is asked to close like the window's close button. Unsaved progress since the last autosave may be lost."
        confirmText: "Stop game"
        danger: true
        onConfirmed: screen.session.stop()
    }
    ConfirmDialog {
        id: shareConfirm
        anchors.centerIn: parent
        title: "Upload this log?"
        message: "latest.log is uploaded to mclo.gs and gets a public link anyone can open. mclo.gs hides IP addresses, but the log can still name your account and file paths."
        confirmText: "Upload"
        onConfirmed: screen.session.share()
    }
}
