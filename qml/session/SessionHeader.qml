import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The running game: its state, session figures, and Stop or Play again.
Rectangle {
    id: header
    required property var page
    signal stopRequested
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
            name: page.info.name || page.session.name
            icon: page.info.icon || ""
            loader: page.info.loader || ""
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
                    color: page.exited ? Colors.subtext : Colors.accent
                    border.width: 3
                    border.color: Qt.rgba(color.r, color.g, color.b, 0.35)
                }
                Text {
                    text: page.exited ? (page.session.diagnosis.crashed ? "CRASHED" : "SESSION ENDED") : page.session.state === "starting" ? "STARTING" : "NOW PLAYING"
                    color: Colors.brass
                    font.family: Colors.displayFont
                    font.pixelSize: Typography.caption
                    font.letterSpacing: 2
                }
            }
            Text {
                Layout.fillWidth: true
                text: page.session.name
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: Typography.pageTitle
                font.letterSpacing: 1
                elide: Text.ElideRight
            }
        }
        Repeater {
            model: [
                { label: "Session", value: page.clock(page.session.elapsedSecs) },
                { label: "Account", value: page.session.account || "—" },
                { label: "Minecraft", value: page.info.version || "—" }
            ]
            delegate: ColumnLayout {
                required property var modelData
                spacing: 0
                visible: page.width > 900 || modelData.label === "Session"
                Layout.rightMargin: 10
                Text {
                    text: modelData.label
                    color: Colors.subtext
                    font.pixelSize: Typography.caption
                }
                Text {
                    text: modelData.value
                    color: Colors.text
                    font.pixelSize: Typography.cardTitle
                    font.weight: Font.Bold
                }
            }
        }
        ActionButton {
            objectName: "playAgainButton"
            visible: page.exited && !!page.info.instanceId
            text: "▶  Play again"
            primary: true
            implicitWidth: 150
            // A multi-account copy is re-synced from its source on every launch.
            onClicked: page.info.altOf ? page.controller.launchAs(page.info.altOf, page.info.altAccount) : page.controller.play(page.info.instanceId, page.info.name)
        }
        // Dismiss keeps the finished session here and only leaves the page.
        ActionButton {
            text: page.exited ? "Dismiss" : "■  Stop game"
            danger: !page.exited
            implicitWidth: 130
            visible: page.exited || page.session.canStop
            // A game Prismarine only found running is closed out of its tab instead.
            onClicked: !page.exited ? header.stopRequested()
                : page.session !== page.controller.session ? page.controller.games.forget(page.session.instanceId)
                : page.controller.navigate("home")
        }
    }
}
