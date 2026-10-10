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
        component Tab: Rectangle {
            id: chip
            property string key
            property string label
            property string sub
            property bool live: true
            property bool closable: false
            readonly property bool selected: screen.current === key
            signal closeRequested
            implicitWidth: Math.min(260, chipRow.implicitWidth + 28)
            implicitHeight: 40
            radius: 10
            color: selected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16) : chipHover.hovered ? Colors.inset : Colors.surface
            border.color: selected ? Colors.accent : Colors.border
            HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
            TapHandler { onTapped: screen.tab = chip.key }
            RowLayout {
                id: chipRow
                anchors { fill: parent; leftMargin: 14; rightMargin: 14 }
                spacing: 8
                Rectangle {
                    implicitWidth: 8
                    implicitHeight: 8
                    radius: 4
                    color: chip.live ? Colors.accent : Colors.subtext
                    visible: chip.key !== "all"
                }
                Text {
                    Layout.fillWidth: true
                    text: chip.label
                    color: chip.selected ? Colors.text : Colors.subtext
                    font.pixelSize: 13
                    font.weight: chip.selected ? Font.DemiBold : Font.Normal
                    elide: Text.ElideRight
                }
                Text {
                    visible: !!chip.sub
                    text: chip.sub
                    color: Colors.subtext
                    font.pixelSize: 11
                }
                Text {
                    visible: chip.closable
                    text: "✕"
                    color: Colors.subtext
                    font.pixelSize: 11
                    TapHandler { onTapped: chip.closeRequested() }
                }
            }
        }
        Tab {
            objectName: "allGamesTab"
            key: "all"
            label: "All games"
            sub: screen.controller.games ? Math.round(screen.controller.games.system.cpuPercent || 0) + "% CPU" : ""
        }
        Repeater {
            model: screen.running
            delegate: Tab {
                required property var modelData
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

    // Nothing launched yet: quick play from the most recent instances.
    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(560, parent.width - 64)
        visible: !screen.session.active && !screen.hardware
        spacing: 16
        Text { Layout.alignment: Qt.AlignHCenter; text: "Nothing running"; color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: 30 }
        Text {
            Layout.fillWidth: true
            horizontalAlignment: Text.AlignHCenter
            text: "Start an instance and its live log, memory use and launch steps appear here."
            color: Colors.subtext
            font.pixelSize: 14
            wrapMode: Text.Wrap
        }
        Repeater {
            model: screen.controller.instances.allInstances.slice().sort((a, b) => b.lastLaunchMs - a.lastLaunchMs).slice(0, 4)
            delegate: Rectangle {
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: 60
                radius: 12
                color: Colors.surface
                border.color: Colors.border
                RowLayout {
                    anchors { fill: parent; margins: 10; leftMargin: 14 }
                    spacing: 12
                    InstanceIcon { size: 36; icon: modelData.icon || ""; name: modelData.name; loader: modelData.loader }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 0
                        Text { Layout.fillWidth: true; text: modelData.name; color: Colors.text; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Text { text: modelData.loader + " · " + modelData.version + " · " + modelData.lastPlayed; color: Colors.subtext; font.pixelSize: 12 }
                    }
                    ActionButton { text: "▶ Play"; primary: true; implicitWidth: 96; implicitHeight: 36; onClicked: screen.controller.play(modelData.instanceId, modelData.name) }
                }
            }
        }
    }
    ColumnLayout {
        visible: screen.session.active && !screen.hardware
        anchors { left: parent.left; right: parent.right; bottom: parent.bottom; top: tabs.bottom; margins: 20; topMargin: tabs.visible ? 14 : 0 }
        spacing: 18
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 92
            radius: 4
            color: Colors.hero
            border.color: Qt.rgba(Colors.brass.r, Colors.brass.g, Colors.brass.b, Colors.decoFrames ? 0.3 : 0)
            RowLayout {
                anchors.fill: parent
                anchors.margins: 14
                anchors.leftMargin: 18
                anchors.rightMargin: 18
                spacing: 16
                InstanceIcon {
                    size: 58
                    name: screen.info.name || screen.session.name
                    icon: screen.info.icon || ""
                    loader: screen.info.loader || ""
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        spacing: 8
                        Rectangle {
                            width: 10
                            height: 10
                            radius: 5
                            color: screen.exited ? Colors.subtext : Colors.accent
                            border.width: 3
                            border.color: Qt.rgba(color.r, color.g, color.b, 0.35)
                        }
                        Text {
                            text: screen.exited ? (screen.session.diagnosis.crashed ? "CRASHED" : "SESSION ENDED") : screen.session.state === "starting" ? "STARTING" : "NOW PLAYING"
                            color: Colors.brass
                            font.family: Colors.displayFont
                            font.pixelSize: 11
                            font.letterSpacing: 2
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: screen.session.name
                        color: Colors.bone
                        font.family: Colors.displayFont
                        font.pixelSize: 30
                        font.letterSpacing: 1
                        elide: Text.ElideRight
                    }
                }
                Repeater {
                    model: [
                        { label: "Session", value: screen.clock(screen.session.elapsedSecs) },
                        { label: "Account", value: screen.session.account || "—" },
                        { label: "Minecraft", value: screen.info.version || "—" }
                    ]
                    delegate: ColumnLayout {
                        required property var modelData
                        spacing: 0
                        visible: screen.width > 900 || modelData.label === "Session"
                        Layout.rightMargin: 10
                        Text {
                            text: modelData.label
                            color: Colors.subtext
                            font.pixelSize: 11
                        }
                        Text {
                            text: modelData.value
                            color: Colors.text
                            font.pixelSize: 19
                            font.weight: Font.Bold
                        }
                    }
                }
                ActionButton {
                    objectName: "playAgainButton"
                    visible: screen.exited && !!screen.info.instanceId
                    text: "▶  Play again"
                    primary: true
                    implicitWidth: 150
                    // A multi-account copy is re-synced from its source on every launch.
                    onClicked: screen.info.altOf ? screen.controller.launchAs(screen.info.altOf, screen.info.altAccount) : screen.controller.play(screen.info.instanceId, screen.info.name)
                }
                // Dismiss keeps the finished session here and only leaves the page.
                ActionButton {
                    text: screen.exited ? "Dismiss" : "■  Stop game"
                    danger: !screen.exited
                    implicitWidth: 130
                    visible: screen.exited || screen.session.canStop
                    // A game Prismarine only found running is closed out of its tab instead.
                    onClicked: !screen.exited ? stopConfirm.open()
                        : screen.session !== screen.controller.session ? screen.controller.games.forget(screen.session.instanceId)
                        : screen.controller.navigate("home")
                }
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 18
            ColumnLayout {
                Layout.preferredWidth: 270
                Layout.maximumWidth: 270
                Layout.fillHeight: true
                spacing: 14
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: steps.implicitHeight + 32
                    radius: 14
                    color: Colors.surface
                    border.color: Colors.border
                    ColumnLayout {
                        id: steps
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 7
                        Text {
                            text: "Launch"
                            color: Colors.bone
                            font.family: Colors.displayFont
                            font.pixelSize: 20
                            font.letterSpacing: 2
                            Layout.bottomMargin: 4
                        }
                        Repeater {
                            model: screen.session.steps
                            delegate: RowLayout {
                                required property var modelData
                                spacing: 10
                                Text {
                                    text: modelData.done ? "✓" : "·"
                                    color: modelData.done ? Colors.accent : Colors.subtext
                                    font.pixelSize: 13
                                    Layout.preferredWidth: 10
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: modelData.title
                                    color: modelData.done ? Colors.text : Colors.subtext
                                    font.pixelSize: 13
                                    elide: Text.ElideRight
                                }
                            }
                        }
                    }
                }
                Rectangle {
                    objectName: "crashHelper"
                    Layout.fillWidth: true
                    implicitHeight: crash.implicitHeight + 32
                    visible: screen.exited && !!screen.session.diagnosis.crashed
                    radius: 14
                    color: Colors.surface
                    border.color: Colors.warning
                    ColumnLayout {
                        id: crash
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 10
                        Text {
                            text: "Crash helper"
                            color: Colors.bone
                            font.family: Colors.displayFont
                            font.pixelSize: 20
                            font.letterSpacing: 2
                        }
                        CrashHelp {
                            Layout.fillWidth: true
                            controller: screen.controller
                            instanceId: screen.session.instanceId
                            diagnosis: screen.session.diagnosis
                        }
                    }
                }
                Rectangle {
                    Layout.fillWidth: true
                    implicitHeight: memory.implicitHeight + 32
                    radius: 14
                    color: Colors.surface
                    border.color: Colors.border
                    visible: screen.session.tracksProcess && screen.session.memoryMiB > 0
                    ColumnLayout {
                        id: memory
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "Memory"
                                color: Colors.bone
                                font.family: Colors.displayFont
                                font.pixelSize: 20
                                font.letterSpacing: 2
                            }
                            Text {
                                text: screen.session.memoryMiB ? (screen.session.memoryMiB / 1024).toFixed(1) + " GiB" + (screen.session.maxMemoryMiB ? " of " + (screen.session.maxMemoryMiB / 1024).toFixed(0) + " GiB" : "") : "—"
                                color: Colors.subtext
                                font.pixelSize: 11
                            }
                        }
                        MemoryGraph {
                            samples: screen.session.memoryHistory
                            ceiling: screen.session.maxMemoryMiB
                        }
                        Text {
                            Layout.fillWidth: true
                            text: "Resident memory of the game process, sampled every few seconds."
                            color: Colors.subtext
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                    }
                }
                Rectangle {
                    objectName: "gameCpuCard"
                    Layout.fillWidth: true
                    implicitHeight: cpuCard.implicitHeight + 32
                    radius: 14
                    color: Colors.surface
                    border.color: Colors.border
                    visible: !!screen.stats && !!screen.stats.pid && !screen.exited
                    ColumnLayout {
                        id: cpuCard
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 8
                        RowLayout {
                            Layout.fillWidth: true
                            Text {
                                Layout.fillWidth: true
                                text: "CPU"
                                color: Colors.bone
                                font.family: Colors.displayFont
                                font.pixelSize: 20
                                font.letterSpacing: 2
                            }
                            Text {
                                text: screen.stats ? screen.stats.cpuPercent.toFixed(1) + "% of the machine" : ""
                                color: Colors.subtext
                                font.pixelSize: 11
                            }
                        }
                        MemoryGraph {
                            samples: screen.stats ? screen.stats.cpuHistory : []
                            tint: Colors.series[0]
                        }
                        TextLink {
                            text: "Whole machine and GPUs →"
                            pixelSize: 11
                            onClicked: screen.tab = "all"
                        }
                    }
                }
                GridLayout {
                    Layout.fillWidth: true
                    columns: 2
                    columnSpacing: 10
                    rowSpacing: 10
                    Repeater {
                        model: [
                            { label: "Mods", value: String(screen.info.mods || 0), tint: Colors.text },
                            { label: "Warnings", value: String(screen.session.warnings), tint: screen.session.warnings ? Colors.warning : Colors.text },
                            { label: "Errors", value: String(screen.session.errors), tint: screen.session.errors ? Colors.danger : Colors.text },
                            { label: "Total played", value: screen.info.played || "—", tint: Colors.text }
                        ]
                        delegate: Rectangle {
                            required property var modelData
                            Layout.fillWidth: true
                            implicitHeight: 54
                            radius: 10
                            color: Colors.surface
                            border.color: Colors.border
                            Column {
                                anchors.fill: parent
                                anchors.margins: 11
                                spacing: 2
                                Text {
                                    text: modelData.label
                                    color: Colors.subtext
                                    font.pixelSize: 11
                                }
                                Text {
                                    text: modelData.value
                                    color: modelData.tint
                                    font.pixelSize: 17
                                    font.weight: Font.Bold
                                }
                            }
                        }
                    }
                }
                Item {
                    Layout.fillHeight: true
                }
            }
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
