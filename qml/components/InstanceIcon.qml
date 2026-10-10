import QtQuick

// Instance icon, or a coloured letter tile when the icon is built into Prism.
Rectangle {
    id: root
    property string icon
    property string name
    property string loader
    property color tint: Colors.coverColor(name)
    property int size: 64

    width: size
    height: size
    radius: size * 0.24
    color: Colors.surfaceHi
    border.width: 1
    border.color: Qt.rgba(1, 1, 1, 0.08)

    Image {
        id: image
        anchors.fill: parent
        anchors.margins: root.size * 0.1
        source: root.icon
        fillMode: Image.PreserveAspectFit
        asynchronous: true
        smooth: true
        mipmap: true
        visible: status === Image.Ready
    }

    Rectangle {
        anchors.fill: parent
        radius: parent.radius
        visible: image.status !== Image.Ready
        color: root.tint
        Text {
            anchors.centerIn: parent
            text: root.name.length > 0 ? root.name.charAt(0).toUpperCase() : "?"
            color: "#10161c"
            font.family: Colors.pixelFont
            font.pixelSize: root.size * 0.42
            font.weight: Font.Black
        }
    }
}
