import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "All games": the whole machine's CPU, memory and GPUs next to every running game's share.
Flickable {
    id: view
    required property var controller
    readonly property var system: controller.games ? controller.games.system : ({})
    readonly property var games: controller.games ? controller.games.games : []
    signal openGame(string instanceId)
    contentHeight: column.implicitHeight
    clip: true
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}

    function gib(mib) {
        return (mib / 1024).toFixed(1) + " GiB";
    }
    function clock(secs) {
        const pad = n => (n < 10 ? "0" : "") + n;
        return Math.floor(secs / 3600) + ":" + pad(Math.floor(secs / 60) % 60) + ":" + pad(secs % 60);
    }

    component Meter: Rectangle {
        id: meter
        property string title
        property string value
        property string detail
        property var samples: []
        property real ceiling: 100
        property color tint: Colors.accent
        Layout.fillWidth: true
        Layout.minimumWidth: 240
        implicitHeight: meterColumn.implicitHeight + 32
        radius: 14
        color: Colors.surface
        border.color: Colors.border
        ColumnLayout {
            id: meterColumn
            anchors.fill: parent
            anchors.margins: 16
            spacing: 8
            RowLayout {
                Layout.fillWidth: true
                Text {
                    Layout.fillWidth: true
                    text: meter.title
                    color: Colors.bone
                    font.family: Colors.displayFont
                    font.pixelSize: 18
                    font.letterSpacing: 1.5
                    elide: Text.ElideRight
                }
                Text {
                    text: meter.value
                    color: meter.tint
                    font.pixelSize: 20
                    font.weight: Font.Bold
                }
            }
            MemoryGraph {
                Layout.preferredHeight: 70
                samples: meter.samples || []
                ceiling: meter.ceiling
                tint: meter.tint
            }
            Text {
                Layout.fillWidth: true
                text: meter.detail
                color: Colors.subtext
                font.pixelSize: 11
                elide: Text.ElideRight
            }
        }
    }

    ColumnLayout {
        id: column
        width: view.width
        spacing: 18
        GridLayout {
            Layout.fillWidth: true
            columns: Math.max(1, Math.min(2 + (view.system.gpus || []).length, Math.floor(view.width / 280)))
            columnSpacing: 14
            rowSpacing: 14
            Meter {
                objectName: "cpuMeter"
                title: "CPU"
                value: Math.round(view.system.cpuPercent || 0) + "%"
                detail: (view.system.cores || 0) + " threads · whole machine"
                samples: view.system.cpuHistory
                tint: Colors.series[0]
            }
            Meter {
                objectName: "ramMeter"
                title: "Memory"
                value: view.gib(view.system.ramUsedMiB || 0)
                detail: "of " + view.gib(view.system.ramTotalMiB || 0) + " · games use " + view.gib(view.games.reduce((sum, g) => sum + (g.memoryMiB || 0), 0))
                samples: view.system.ramHistory
                ceiling: view.system.ramTotalMiB || 0
                tint: Colors.series[2]
            }
            Repeater {
                model: view.system.gpus || []
                delegate: Meter {
                    required property var modelData
                    required property int index
                    title: modelData.name
                    value: Math.round(modelData.util) + "%"
                    detail: modelData.memTotalMiB ? "VRAM " + view.gib(modelData.memUsedMiB) + " of " + view.gib(modelData.memTotalMiB) : "GPU load"
                    samples: modelData.history
                    tint: Colors.series[(3 + index) % Colors.series.length]
                }
            }
        }

        Rectangle {
            Layout.fillWidth: true
            implicitHeight: gameList.implicitHeight + 32
            radius: 14
            color: Colors.surface
            border.color: Colors.border
            ColumnLayout {
                id: gameList
                anchors.fill: parent
                anchors.margins: 16
                spacing: 10
                Text {
                    text: "Running games"
                    color: Colors.bone
                    font.family: Colors.displayFont
                    font.pixelSize: 18
                    font.letterSpacing: 1.5
                }
                Text {
                    visible: view.games.length === 0
                    text: "No game is running right now."
                    color: Colors.subtext
                    font.pixelSize: 13
                }
                Repeater {
                    model: view.games
                    delegate: Rectangle {
                        id: row
                        required property var modelData
                        readonly property double share: view.system.ramUsedMiB ? modelData.memoryMiB / view.system.ramUsedMiB : 0
                        Layout.fillWidth: true
                        implicitHeight: 58
                        radius: 10
                        color: hover.hovered ? Colors.inset : "transparent"
                        HoverHandler { id: hover }
                        TapHandler { onTapped: view.openGame(row.modelData.instanceId) }
                        RowLayout {
                            anchors { fill: parent; leftMargin: 8; rightMargin: 8 }
                            spacing: 12
                            InstanceIcon { size: 36; icon: row.modelData.icon || ""; name: row.modelData.name; loader: row.modelData.loader || "" }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 1
                                Text {
                                    Layout.fillWidth: true
                                    text: row.modelData.name + (row.modelData.altOf ? "  ·  copy" : "")
                                    color: Colors.text
                                    font.pixelSize: 14
                                    font.weight: Font.DemiBold
                                    elide: Text.ElideRight
                                }
                                Text {
                                    text: (row.modelData.account ? "as " + row.modelData.account + " · " : "") + (row.modelData.state === "exited" ? "ended" : view.clock(row.modelData.elapsedSecs))
                                          + (row.modelData.pid ? " · pid " + row.modelData.pid : "")
                                    color: Colors.subtext
                                    font.pixelSize: 12
                                }
                            }
                            Repeater {
                                model: [
                                    { label: "CPU", value: row.modelData.pid ? row.modelData.cpuPercent.toFixed(1) + "%" : "—" },
                                    { label: "Memory", value: row.modelData.memoryMiB ? view.gib(row.modelData.memoryMiB) : "—" }
                                ]
                                delegate: ColumnLayout {
                                    required property var modelData
                                    spacing: 0
                                    Layout.preferredWidth: 76
                                    Text { text: modelData.label; color: Colors.subtext; font.pixelSize: 11 }
                                    Text { text: modelData.value; color: Colors.text; font.pixelSize: 15; font.weight: Font.Bold }
                                }
                            }
                            Text { text: "›"; color: Colors.subtext; font.pixelSize: 20 }
                        }
                        // How much of the used memory this game holds.
                        Rectangle {
                            anchors { left: parent.left; bottom: parent.bottom; leftMargin: 8 }
                            height: 2
                            radius: 1
                            width: (parent.width - 16) * Math.min(1, row.share)
                            color: Colors.series[2]
                            opacity: 0.6
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            text: "Sampled every 2 seconds. Game CPU is a share of the whole machine."
                  + ((view.system.gpus || []).length ? "" : " This system does not report GPU load here.")
            color: Colors.subtext
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
    }
}
