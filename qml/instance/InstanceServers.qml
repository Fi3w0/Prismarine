import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// The instance's multiplayer list with live status; Join launches straight into a server.
ColumnLayout {
    id: serversTab
    required property var controller
    readonly property var list: controller.serverList
    readonly property var contents: controller.details
    readonly property bool active: controller.instanceTab === "servers"
    property var removing: ({})

    function sync() {
        if (active && list && contents.instanceId && list.instanceId !== contents.instanceId)
            list.load(contents.instanceId);
    }
    onActiveChanged: sync()
    Connections {
        target: serversTab.contents
        function onInstanceIdChanged() { serversTab.sync(); }
    }

    anchors {
        fill: parent
        margins: 28
    }
    visible: active
    spacing: 14
    RowLayout {
        Layout.fillWidth: true
        spacing: 12
        Text {
            text: "Servers"
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: 28
            font.letterSpacing: 2
        }
        Text {
            Layout.alignment: Qt.AlignBaseline
            text: serversTab.list ? serversTab.list.servers.length + " in the multiplayer list" : ""
            color: Colors.subtext
            font.pixelSize: 13
        }
        Item {
            Layout.fillWidth: true
        }
        InputField {
            id: serverSearch
            objectName: "serverSearch"
            visible: !!serversTab.list && serversTab.list.servers.length > 4
            Layout.preferredWidth: 220
            placeholderText: "Search servers…"
            font.pixelSize: 13
        }
        ActionButton {
            text: "↻ Refresh"
            implicitWidth: contentItem.implicitWidth + 32
            enabled: !!serversTab.list
            onClicked: serversTab.list.refresh()
        }
        ActionButton {
            objectName: "addServerButton"
            text: "+ Add server"
            primary: true
            implicitWidth: contentItem.implicitWidth + 32
            enabled: !!serversTab.list
            onClicked: addDialog.open()
        }
    }
    ListView {
        id: rows
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        spacing: 8
        model: !serversTab.list ? [] : serverSearch.text ? serversTab.list.servers.filter(it => ((it.name || "") + " " + it.address).toLowerCase().indexOf(serverSearch.text.toLowerCase()) >= 0) : serversTab.list.servers
        ScrollBar.vertical: ScrollBar {}
        delegate: Rectangle {
            id: row
            required property var modelData
            readonly property var status: serversTab.list.status[modelData.address] || ({})
            readonly property bool online: status.state === "online"
            width: ListView.view.width
            implicitHeight: 76
            radius: 12
            color: Colors.surface
            border.color: Colors.border
            RowLayout {
                anchors {
                    fill: parent
                    margins: 12
                }
                spacing: 14
                Rectangle {
                    Layout.preferredWidth: 52
                    Layout.preferredHeight: 52
                    radius: 8
                    color: Colors.surfaceHi
                    Image {
                        anchors.fill: parent
                        anchors.margins: 2
                        source: row.status.favicon || row.modelData.icon || ""
                        smooth: false
                        visible: status === Image.Ready
                    }
                    Text {
                        anchors.centerIn: parent
                        visible: !(row.status.favicon || row.modelData.icon)
                        text: (row.modelData.name || "?").charAt(0).toUpperCase()
                        color: Colors.subtext
                        font.family: Colors.pixelFont
                        font.pixelSize: 20
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 3
                    RowLayout {
                        spacing: 8
                        Text {
                            text: row.modelData.name || "Minecraft Server"
                            color: Colors.text
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            text: row.modelData.address
                            color: Colors.subtext
                            font.pixelSize: 11
                        }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: row.online ? (row.status.motd || "A Minecraft server") : row.status.state === "pinging" ? "Pinging…" : (row.status.reason || "Offline")
                        color: row.online ? Colors.text : Colors.subtext
                        font.pixelSize: 12
                        elide: Text.ElideRight
                        maximumLineCount: 1
                    }
                    Text {
                        visible: row.online && !!row.status.version
                        text: row.status.version || ""
                        color: Colors.subtext
                        font.pixelSize: 10
                    }
                }
                ColumnLayout {
                    spacing: 2
                    Text {
                        Layout.alignment: Qt.AlignRight
                        text: row.online ? row.status.players + " / " + row.status.max : "—"
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Row {
                        Layout.alignment: Qt.AlignRight
                        spacing: 2
                        Repeater {
                            model: 5
                            delegate: Rectangle {
                                required property int index
                                readonly property int bars: !row.online ? 0 : row.status.latency < 80 ? 5 : row.status.latency < 150 ? 4 : row.status.latency < 300 ? 3 : row.status.latency < 600 ? 2 : 1
                                anchors.bottom: parent.bottom
                                width: 3
                                height: 4 + index * 2
                                color: index < bars ? (bars >= 4 ? Colors.success : bars >= 2 ? Colors.warning : Colors.danger) : Colors.border
                            }
                        }
                    }
                    Text {
                        Layout.alignment: Qt.AlignRight
                        visible: row.online
                        text: (row.status.latency || 0) + " ms"
                        color: Colors.subtext
                        font.pixelSize: 10
                    }
                }
                ActionButton {
                    readonly property bool favorite: serversTab.controller.preferences.serverFavorites.some(it => it.instanceId === serversTab.contents.instanceId && it.address.toLowerCase() === row.modelData.address.toLowerCase())
                    compact: true
                    implicitHeight: 36
                    checked: favorite
                    Accessible.name: (favorite ? "Remove " : "Add ") + (row.modelData.name || row.modelData.address) + (favorite ? " from Home" : " to Home")
                    ToolTip.visible: hovered
                    ToolTip.text: favorite ? "Pinned to Home" : "Pin to Home"
                    onClicked: serversTab.controller.preferences.toggleServerFavorite(serversTab.contents.instanceId, row.modelData.name || row.modelData.address, row.modelData.address)
                    LineIcon { anchors.centerIn: parent; name: "star"; tint: parent.favorite ? Colors.brass : Colors.subtext; width: 18; height: 18 }
                }
                ActionButton {
                    text: "▶ Join"
                    primary: true
                    implicitWidth: 88
                    implicitHeight: 36
                    font.pixelSize: 13
                    onClicked: if (serversTab.list.join(row.modelData.index)) {
                        serversTab.controller.notify("Joining " + (row.modelData.name || row.modelData.address) + "…");
                        serversTab.controller.followLaunch(serversTab.contents.instanceId);
                    }
                }
                ActionButton {
                    text: "✕"
                    compact: true
                    implicitHeight: 36
                    Accessible.name: "Remove " + row.modelData.name
                    ToolTip.visible: hovered
                    ToolTip.text: "Remove from the list"
                    onClicked: {
                        serversTab.removing = row.modelData;
                        removeDialog.open();
                    }
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: !rows.count
            horizontalAlignment: Text.AlignHCenter
            text: "No servers yet.\nAdd one here or in Minecraft's multiplayer screen."
            color: Colors.subtext
            font.pixelSize: 14
        }
    }
    ConfirmDialog {
        id: removeDialog
        anchors.centerIn: Overlay.overlay
        title: "Remove " + (serversTab.removing.name || "this server") + "?"
        message: "It leaves this instance's multiplayer list. Minecraft keeps the previous list as servers.dat_old."
        confirmText: "Remove"
        danger: true
        onConfirmed: serversTab.list.remove(serversTab.removing.index)
    }
    MotionDialog {
        id: addDialog
        anchors.centerIn: Overlay.overlay
        modal: true
        width: 420
        padding: 22
        title: "Add server"
        background: Rectangle {
            radius: 14
            color: Colors.surface
            border.color: Colors.border
        }
        onOpened: {
            serverName.text = "";
            serverAddress.text = "";
            serverAddress.forceActiveFocus();
        }
        contentItem: ColumnLayout {
            spacing: 10
            Text {
                text: "Add server"
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: 20
            }
            InputField {
                id: serverName
                Layout.fillWidth: true
                placeholderText: "Name (optional)"
            }
            InputField {
                id: serverAddress
                objectName: "serverAddressField"
                Layout.fillWidth: true
                placeholderText: "play.example.com or 192.168.1.4:25565"
                onAccepted: addButton.clicked()
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Item {
                    Layout.fillWidth: true
                }
                ActionButton {
                    text: "Cancel"
                    implicitWidth: 100
                    onClicked: addDialog.close()
                }
                ActionButton {
                    id: addButton
                    text: "Add"
                    primary: true
                    implicitWidth: 100
                    enabled: serverAddress.text.trim().length > 0
                    onClicked: if (serversTab.list.add(serverName.text, serverAddress.text)) addDialog.close()
                }
            }
        }
    }
}
