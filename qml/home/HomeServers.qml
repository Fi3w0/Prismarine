import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Servers pinned with ☆ in an instance's Servers tab, with live status and Join.
Rectangle {
    id: card
    required property var controller
    readonly property var pinger: controller.homeServers
    readonly property var favorites: controller.preferences.serverFavorites.filter(it => !!controller.instances.getById(it.instanceId).instanceId)
    function refresh() {
        if (pinger && favorites.length) pinger.pingAddresses(favorites.map(it => it.address));
    }
    onFavoritesChanged: refresh()
    Component.onCompleted: refresh()
    Timer { interval: 60000; repeat: true; running: card.visible && card.favorites.length > 0; onTriggered: card.refresh() }
    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 40
    color: Colors.surface
    radius: 16
    border.color: Colors.border
    ColumnLayout {
        id: body
        anchors { fill: parent; margins: 20 }
        spacing: 10
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Favourite servers"
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: 20
                font.letterSpacing: 2
            }
            TextLink {
                visible: card.favorites.length > 0 && !!card.pinger
                text: "↻ Refresh"
                onClicked: card.refresh()
            }
        }
        Text {
            visible: !card.favorites.length
            Layout.fillWidth: true
            text: "Pin servers with the ☆ button in an instance's Servers tab to see who's online and join in one click."
            color: Colors.subtext
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
        GridLayout {
            Layout.fillWidth: true
            visible: card.favorites.length > 0
            columns: card.width >= 900 ? 2 : 1
            columnSpacing: 12
            rowSpacing: 8
            Repeater {
                model: card.favorites
                delegate: Rectangle {
                    id: server
                    required property var modelData
                    readonly property var status: card.pinger ? card.pinger.status[modelData.address] || ({}) : ({})
                    readonly property bool online: status.state === "online"
                    readonly property var instance: card.controller.instances.getById(modelData.instanceId)
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 64
                    radius: 12
                    color: Colors.inset
                    border.color: Colors.border
                    RowLayout {
                        anchors { fill: parent; margins: 10; leftMargin: 12 }
                        spacing: 12
                        Rectangle {
                            implicitWidth: 40
                            implicitHeight: 40
                            radius: 8
                            color: Colors.surfaceHi
                            Image { id: favicon; anchors.fill: parent; source: server.status.favicon || ""; fillMode: Image.PreserveAspectFit; smooth: false }
                            LineIcon { anchors.centerIn: parent; visible: favicon.status !== Image.Ready; name: "world"; tint: Colors.subtext }
                        }
                        ColumnLayout {
                            Layout.fillWidth: true
                            spacing: 2
                            Text { Layout.fillWidth: true; text: server.modelData.name; color: Colors.text; font.pixelSize: 14; font.weight: Font.DemiBold; elide: Text.ElideRight }
                            RowLayout {
                                spacing: 6
                                Rectangle {
                                    implicitWidth: 8; implicitHeight: 8; radius: 4
                                    color: server.online ? Colors.success : server.status.state === "pinging" ? Colors.subtext : Colors.danger
                                }
                                Text {
                                    Layout.fillWidth: true
                                    text: (server.online ? server.status.players + " / " + server.status.max + " online · " + server.status.latency + " ms"
                                           : server.status.state === "pinging" ? "Pinging…" : "Offline")
                                          + " · " + (server.instance.name || "")
                                    color: Colors.subtext
                                    font.pixelSize: 12
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        ActionButton {
                            text: "▶ Join"
                            primary: true
                            implicitWidth: 84
                            implicitHeight: 36
                            font.pixelSize: 13
                            onClicked: {
                                if (card.controller.instances.launchServer(server.modelData.instanceId, server.modelData.address)) {
                                    card.controller.notify("Joining " + server.modelData.name + "…");
                                    card.controller.followLaunch(server.modelData.instanceId);
                                }
                            }
                        }
                        ActionButton {
                            compact: true
                            implicitHeight: 36
                            Accessible.name: "Unpin " + server.modelData.name
                            ToolTip.visible: hovered
                            ToolTip.text: "Unpin from Home"
                            onClicked: card.controller.preferences.toggleServerFavorite(server.modelData.instanceId, server.modelData.name, server.modelData.address)
                            LineIcon { anchors.centerIn: parent; name: "star"; tint: Colors.brass; width: 16; height: 16 }
                        }
                    }
                }
            }
        }
    }
}
