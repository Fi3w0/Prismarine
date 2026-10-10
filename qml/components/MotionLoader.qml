import QtQuick

Loader {
    id: host
    property bool backwards: false
    onLoaded: entrance.restart()
    transform: Translate { id: offset }
    ParallelAnimation {
        id: entrance
        NumberAnimation { target: host; property: "opacity"; from: Colors.animations ? 0 : 1; to: 1; duration: Colors.animations ? 340 : 0; easing.type: Easing.OutCubic }
        NumberAnimation { target: offset; property: "x"; from: Colors.animations ? (host.backwards ? -22 : 22) : 0; to: 0; duration: Colors.animations ? 420 : 0; easing.type: Easing.OutCubic }
    }
}
