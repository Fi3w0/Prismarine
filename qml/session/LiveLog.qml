import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The running game's latest.log with level chips, search, follow, copy and share.
Rectangle {
    id: panel
    required property var controller
    // The game whose log is shown; Now playing switches it between running games.
    property var session: controller.session
    property bool follow: true
    readonly property bool narrow: width < 680
    signal shareRequested
    color: Colors.surface
    radius: 14
    border.color: Colors.border
    ColumnLayout {
        anchors.fill: parent
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 8
            Text {
                visible: !panel.narrow
                text: "Live log"
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: 20
                font.letterSpacing: 2
                Layout.rightMargin: 8
            }
            Repeater {
                model: [
                    { label: "All", level: "", tint: Colors.accent },
                    { label: "Info", level: "INFO", tint: Colors.text },
                    { label: "Warn", level: "WARN", tint: Colors.warning },
                    { label: "Error", level: "ERROR", tint: Colors.danger }
                ]
                delegate: Chip {
                    required property var modelData
                    text: modelData.label
                    interactive: true
                    tint: modelData.tint
                    active: panel.session.log.level === modelData.level
                    onClicked: panel.session.log.level = modelData.level
                }
            }
            InputField {
                Layout.fillWidth: true
                Layout.minimumWidth: 70
                implicitHeight: 32
                font.pixelSize: 12
                placeholderText: "Filter log"
                onTextChanged: panel.session.log.text = text
            }
            TextLink {
                text: panel.follow ? "Following" : "Follow"
                tint: panel.follow ? Colors.accent : Colors.subtext
                underline: false
                onClicked: {
                    panel.follow = !panel.follow;
                    if (panel.follow)
                        lines.positionViewAtEnd();
                }
            }
            ActionButton {
                text: "Copy"
                implicitWidth: 64
                implicitHeight: 32
                font.pixelSize: 12
                onClicked: {
                    panel.session.copyLog();
                    panel.controller.notify("Log copied");
                }
            }
            ActionButton {
                text: panel.session.sharing ? "Uploading…" : panel.narrow ? "Share" : "Share (mclo.gs)"
                implicitWidth: panel.narrow ? 72 : 120
                implicitHeight: 32
                font.pixelSize: 12
                enabled: !panel.session.sharing
                onClicked: panel.shareRequested()
            }
        }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: 1
            color: Colors.border
        }
        ListView {
            id: lines
            objectName: "liveLogLines"
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 10
            clip: true
            model: panel.session.log
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            onCountChanged: if (panel.follow) Qt.callLater(positionViewAtEnd)
            onMovementStarted: panel.follow = false
            delegate: Rectangle {
                id: row
                required property string text
                required property string level
                width: ListView.view.width
                implicitHeight: label.implicitHeight + 4
                radius: 4
                color: level === "ERROR" ? Qt.rgba(Colors.danger.r, Colors.danger.g, Colors.danger.b, 0.12) : level === "WARN" ? Qt.rgba(0.94, 0.64, 0.37, 0.10) : "transparent"
                Text {
                    id: label
                    anchors {
                        left: parent.left
                        right: parent.right
                        verticalCenter: parent.verticalCenter
                        leftMargin: 6
                        rightMargin: 6
                    }
                    text: row.text
                    color: row.level === "ERROR" ? Colors.danger : row.level === "WARN" ? Colors.warning : row.level === "DEBUG" ? Colors.subtext : Colors.text
                    font.family: "monospace"
                    font.pixelSize: 12
                    wrapMode: Text.WrapAnywhere
                    maximumLineCount: 6
                    elide: Text.ElideRight
                    textFormat: Text.PlainText
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !lines.count
                width: parent.width - 40
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: panel.session.log.text || panel.session.log.level ? "No lines match this filter." : "Waiting for the game to write its log…"
                color: Colors.subtext
                font.pixelSize: 13
            }
        }
        Text {
            Layout.margins: 12
            Layout.topMargin: 0
            visible: panel.session.state !== "exited"
            text: "▌ " + (panel.follow ? "following live output" : "paused · scroll to the end or press Follow")
            color: Colors.accent
            font.family: "monospace"
            font.pixelSize: 11
        }
    }
}
