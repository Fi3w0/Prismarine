import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Servers pinned with ☆ in an instance's Servers tab, with live status and Join.
Rectangle {
    id: card
    required property var controller
    property string targetId: controller.current.instanceId || (controller.instances.allInstances[0] || {}).instanceId || ""
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
                font.pixelSize: Typography.sectionTitle
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
            text: "No servers pinned yet. Add one and see who is online before you launch."
            color: Colors.subtext
            font.pixelSize: Typography.body
            wrapMode: Text.Wrap
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text { text: qsTr("Join with"); color: Colors.subtext; font.pixelSize: Typography.bodySmall }
                SelectBox {
                    id: targetPicker
                    objectName: "homeServerTarget"
                    Layout.fillWidth: true
                    model: card.controller.instances.allInstances
                    textRole: "name"
                    currentIndex: model.findIndex(it => it.instanceId === card.targetId)
                    displayText: currentIndex < 0 ? qsTr("Choose an instance…") : currentText
                    onActivated: card.targetId = model[currentIndex].instanceId
                }
            }
            RowLayout {
                Layout.fillWidth: true
                InputField {
                    id: address
                    objectName: "homeServerAddress"
                    Layout.fillWidth: true
                    placeholderText: "play.example.net"
                    Accessible.name: qsTr("Server address")
                    onAccepted: addServer.clicked()
                }
                ActionButton {
                    id: addServer
                    objectName: "homeAddServer"
                    text: qsTr("Add server")
                    implicitWidth: 120
                    primary: true
                    enabled: targetPicker.currentIndex >= 0 && !!address.text.trim()
                    onClicked: {
                        if (!enabled || !card.controller.instances.getById(card.targetId).instanceId) return;
                        if (card.controller.preferences.addServerFavorite(card.targetId, address.text.trim(), address.text)) {
                            address.clear(); card.controller.notify(qsTr("Server pinned to Home"));
                        }
                    }
                }
            }
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
                            Text { Layout.fillWidth: true; text: server.modelData.name; color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold; elide: Text.ElideRight }
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
                                    font.pixelSize: Typography.bodySmall
                                    elide: Text.ElideRight
                                }
                            }
                        }
                        ActionButton {
                            objectName: "homeJoinServer_" + server.modelData.instanceId
                            text: "▶ Join"
                            primary: true
                            implicitWidth: 84
                            implicitHeight: 36
                            font.pixelSize: Typography.body
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
