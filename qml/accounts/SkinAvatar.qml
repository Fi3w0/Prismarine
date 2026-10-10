import QtQuick

Rectangle {
    id: avatar
    property string skin: ""
    property int size: 36
    implicitWidth: size
    implicitHeight: size
    radius: 9
    color: Colors.surfaceHi
    Image { id: face; anchors.fill: parent; anchors.margins: 4; source: avatar.skin; sourceClipRect: Qt.rect(8, 8, 8, 8); smooth: false; asynchronous: true }
    Image { anchors.fill: parent; anchors.margins: 2; source: avatar.skin; sourceClipRect: Qt.rect(40, 8, 8, 8); smooth: false; asynchronous: true }
    LineIcon { anchors.centerIn: parent; name: "accounts"; visible: face.status !== Image.Ready }
}
