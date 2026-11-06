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
    Image {
        anchors.centerIn: parent
        width: avatar.size * 0.65
        height: width
        sourceSize: Qt.size(width, height)
        source: Colors.light ? "qrc:/assets/icons/profile-dark.svg" : "qrc:/assets/icons/profile-light.svg"
        visible: face.status !== Image.Ready
    }
}
