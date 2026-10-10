import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Hours per week for the last 12 weeks, and where this month's time went.
Rectangle {
    id: panel
    required property var controller
    readonly property var history: controller.playtime
    readonly property var weeks: history ? history.weeks : []
    readonly property real peak: Math.max(3600, ...weeks.map(w => w.secs))
    readonly property var leaders: history ? history.topThisMonth : []

    function duration(secs) {
        if (secs < 3600)
            return Math.round(secs / 60) + " min";
        return (secs / 3600).toFixed(secs < 36000 ? 1 : 0) + " h";
    }

    visible: !!history
    Layout.fillWidth: true
    Layout.preferredHeight: 270
    color: Colors.surface
    radius: 16
    border.color: Colors.border
    RowLayout {
        anchors {
            fill: parent
            margins: 20
        }
        spacing: 28
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            spacing: 6
            RowLayout {
                Layout.fillWidth: true
                spacing: 18
                Text {
                    text: "Playtime"
                    color: Colors.bone
                    font.family: Colors.displayFont
                    font.pixelSize: 20
                    font.letterSpacing: 2
                }
                Text {
                    Layout.alignment: Qt.AlignBaseline
                    text: panel.history ? panel.duration(panel.history.thisWeekSecs) + " this week" : ""
                    color: Colors.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.alignment: Qt.AlignBaseline
                    visible: !!panel.history && panel.history.streakDays > 1
                    text: panel.history ? panel.history.streakDays + "-day streak" : ""
                    color: Colors.subtext
                    font.pixelSize: 12
                }
                Item {
                    Layout.fillWidth: true
                }
                Text {
                    text: panel.history ? "Tracking since " + panel.history.trackedSince : ""
                    color: Colors.subtext
                    font.pixelSize: 11
                }
            }
            // The plot: one bar per week, current week labelled directly.
            Item {
                id: plot
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.topMargin: 8
                readonly property real slot: width / Math.max(1, panel.weeks.length)
                Rectangle {
                    anchors.bottom: axis.top
                    width: parent.width
                    height: 1
                    color: Colors.border
                }
                Repeater {
                    model: panel.weeks
                    delegate: Item {
                        id: week
                        required property var modelData
                        required property int index
                        readonly property bool current: index === panel.weeks.length - 1
                        x: index * plot.slot
                        width: plot.slot
                        height: plot.height - axis.height
                        // 2px gap between bars; rounded data end, anchored on the baseline.
                        Item {
                            id: bar
                            anchors.bottom: parent.bottom
                            anchors.horizontalCenter: parent.horizontalCenter
                            width: Math.min(28, parent.width - 2)
                            height: week.modelData.secs > 0 ? Math.max(3, (parent.height - 18) * week.modelData.secs / panel.peak) : 0
                            clip: true
                            opacity: hover.hovered || week.current ? 1 : 0.72
                            // Rounded data end on top, square on the baseline: the overhang is clipped away.
                            Rectangle {
                                width: parent.width
                                height: parent.height + radius
                                radius: Math.min(4, width / 2)
                                color: Colors.accent
                            }
                        }
                        Text {
                            anchors.bottom: bar.top
                            anchors.bottomMargin: 3
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: week.current && week.modelData.secs > 0
                            text: panel.duration(week.modelData.secs)
                            color: Colors.text
                            font.pixelSize: 10
                            font.weight: Font.DemiBold
                        }
                        Text {
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 2
                            anchors.horizontalCenter: parent.horizontalCenter
                            visible: !week.modelData.tracked
                            text: "·"
                            color: Colors.border
                            font.pixelSize: 14
                        }
                        HoverHandler { id: hover }
                        ToolTip.visible: hover.hovered
                        ToolTip.delay: 0
                        ToolTip.text: "Week of " + week.modelData.label + ": " + (week.modelData.tracked ? panel.duration(week.modelData.secs) : "before tracking")
                    }
                }
                Row {
                    id: axis
                    anchors.bottom: parent.bottom
                    width: parent.width
                    height: 16
                    Repeater {
                        model: panel.weeks
                        delegate: Text {
                            required property var modelData
                            required property int index
                            width: plot.slot
                            horizontalAlignment: Text.AlignHCenter
                            // Every other week keeps labels from colliding.
                            text: (panel.weeks.length - 1 - index) % 2 === 0 ? modelData.label : ""
                            color: Colors.subtext
                            font.pixelSize: 9
                        }
                    }
                }
            }
        }
        ColumnLayout {
            Layout.preferredWidth: 260
            Layout.maximumWidth: 280
            Layout.fillHeight: true
            visible: panel.width > 820
            spacing: 8
            Text {
                text: "This month"
                color: Colors.subtext
                font.pixelSize: 12
            }
            Repeater {
                model: panel.leaders
                delegate: ColumnLayout {
                    required property var modelData
                    Layout.fillWidth: true
                    spacing: 3
                    RowLayout {
                        Layout.fillWidth: true
                        Text {
                            Layout.fillWidth: true
                            text: modelData.name
                            color: Colors.text
                            font.pixelSize: 12
                            elide: Text.ElideRight
                        }
                        Text {
                            text: panel.duration(modelData.secs)
                            color: Colors.subtext
                            font.pixelSize: 11
                        }
                    }
                    Rectangle {
                        Layout.preferredWidth: Math.max(4, parent.width * modelData.secs / Math.max(1, panel.leaders[0].secs))
                        Layout.preferredHeight: 4
                        radius: 2
                        color: Colors.accent
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                visible: !panel.leaders.length
                text: "Play something and it shows up here. Time is counted from Prism's totals, so launches from Prism count too."
                color: Colors.subtext
                font.pixelSize: 11
                wrapMode: Text.Wrap
            }
            Item {
                Layout.fillHeight: true
            }
        }
    }
}
