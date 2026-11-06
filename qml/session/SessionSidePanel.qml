import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Beside the live log: launch steps, crash help, memory, CPU and counts.
ColumnLayout {
    required property var page
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
                font.pixelSize: Typography.sectionTitle
                font.letterSpacing: 2
                Layout.bottomMargin: 4
            }
            Repeater {
                model: page.session.steps
                delegate: RowLayout {
                    required property var modelData
                    spacing: 10
                    Text {
                        text: modelData.done ? "✓" : "·"
                        color: modelData.done ? Colors.accent : Colors.subtext
                        font.pixelSize: Typography.body
                        Layout.preferredWidth: 10
                    }
                    Text {
                        Layout.fillWidth: true
                        text: modelData.title
                        color: modelData.done ? Colors.text : Colors.subtext
                        font.pixelSize: Typography.body
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
        visible: page.exited && !!page.session.diagnosis.crashed
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
                font.pixelSize: Typography.sectionTitle
                font.letterSpacing: 2
            }
            CrashHelp {
                Layout.fillWidth: true
                controller: page.controller
                instanceId: page.session.instanceId
                diagnosis: page.session.diagnosis
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: memory.implicitHeight + 32
        radius: 14
        color: Colors.surface
        border.color: Colors.border
        visible: page.session.tracksProcess && page.session.memoryMiB > 0
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
                    font.pixelSize: Typography.sectionTitle
                    font.letterSpacing: 2
                }
                Text {
                    text: page.session.memoryMiB ? (page.session.memoryMiB / 1024).toFixed(1) + " GiB" + (page.session.maxMemoryMiB ? " of " + (page.session.maxMemoryMiB / 1024).toFixed(0) + " GiB" : "") : "—"
                    color: Colors.subtext
                    font.pixelSize: Typography.caption
                }
            }
            MemoryGraph {
                samples: page.session.memoryHistory
                ceiling: page.session.maxMemoryMiB
            }
            Text {
                Layout.fillWidth: true
                text: "Resident memory of the game process, sampled every few seconds."
                color: Colors.subtext
                font.pixelSize: Typography.caption
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
        visible: !!page.stats && !!page.stats.pid && !page.exited
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
                    font.pixelSize: Typography.sectionTitle
                    font.letterSpacing: 2
                }
                Text {
                    text: page.stats ? page.stats.cpuPercent.toFixed(1) + "% of the machine" : ""
                    color: Colors.subtext
                    font.pixelSize: Typography.caption
                }
            }
            MemoryGraph {
                samples: page.stats ? page.stats.cpuHistory : []
                tint: Colors.series[0]
            }
            TextLink {
                text: "Whole machine and GPUs →"
                pixelSize: Typography.caption
                onClicked: page.tab = "all"
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
                { label: "Mods", value: String(page.info.mods || 0), tint: Colors.text },
                { label: "Warnings", value: String(page.session.warnings), tint: page.session.warnings ? Colors.warning : Colors.text },
                { label: "Errors", value: String(page.session.errors), tint: page.session.errors ? Colors.danger : Colors.text },
                { label: "Total played", value: page.info.played || "—", tint: Colors.text }
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
                        font.pixelSize: Typography.caption
                    }
                    Text {
                        text: modelData.value
                        color: modelData.tint
                        font.pixelSize: Typography.valueSmall
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
