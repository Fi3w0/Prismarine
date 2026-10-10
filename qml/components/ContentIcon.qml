import QtQuick

Rectangle {
    id: tile
    property string source: ""
    property string category: "mods"
    property int size: 36
    implicitWidth: size
    implicitHeight: size
    radius: 8
    color: art.status === Image.Ready ? "transparent" : Colors.surfaceHi
    Image { id: art; anchors.fill: parent; source: tile.source; fillMode: Image.PreserveAspectFit; asynchronous: true; smooth: true }
    LineIcon { anchors.centerIn: parent; visible: art.status !== Image.Ready; name: tile.category === "logs" ? "list" : tile.category === "saves" ? "world" : tile.category === "shaderpacks" ? "shaders" : "package"; tint: Colors.subtext }
}
