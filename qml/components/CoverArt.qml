import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Rectangle {
    id: art
    property string instanceId: ""
    property string screenshot: ""
    property string cover: ""
    property bool showScreenshot: false
    property color tint: Colors.coverColor(instanceId)
    readonly property bool hasImage: shot.status === Image.Ready
    readonly property bool software: GraphicsInfo.api === GraphicsInfo.Software
    readonly property real waveOffset: {
        let seed = 0;
        for (let i = 0; i < instanceId.length; ++i) seed = (seed * 31 + instanceId.charCodeAt(i)) >>> 0;
        return (seed % 101) / 100;
    }
    radius: Colors.cornerStyle === "angular" ? 2 : 12
    color: Qt.darker(tint, 3.7)
    clip: true
    Image {
        id: shot
        anchors.fill: parent
        source: art.cover || (art.showScreenshot ? art.screenshot : "")
        sourceSize.width: 600
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: art.software && art.hasImage
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: art.radius
        visible: false
        layer.enabled: !art.software
    }
    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: !art.software && art.hasImage
        maskEnabled: true
        maskSource: mask
        brightness: -0.15
    }
    Rectangle {
        anchors.fill: parent
        visible: shot.status === Image.Ready
        radius: art.radius
        gradient: Gradient {
            GradientStop {
                position: 0
                color: "#220a1016"
            }
            GradientStop {
                position: 0.5
                color: "#110a1016"
            }
            GradientStop {
                position: 1
                color: "#ee0a1016"
            }
        }
    }
    Item {
        anchors.fill: parent
        visible: !art.hasImage
        Shape {
            anchors.fill: parent
            ShapePath {
                strokeColor: "transparent"
                fillColor: Qt.darker(art.tint, 2.7)
                startX: 0; startY: art.height * (0.34 + art.waveOffset * 0.12)
                PathCubic {
                    control1X: art.width * 0.28; control1Y: art.height * (0.23 + art.waveOffset * 0.12)
                    control2X: art.width * 0.72; control2Y: art.height * 0.52
                    x: art.width; y: art.height * 0.42
                }
                PathLine { x: art.width; y: art.height - art.radius }
                PathQuad { x: art.width - art.radius; y: art.height; controlX: art.width; controlY: art.height }
                PathLine { x: art.radius; y: art.height }
                PathQuad { x: 0; y: art.height - art.radius; controlX: 0; controlY: art.height }
                PathLine { x: 0; y: art.height * (0.34 + art.waveOffset * 0.12) }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: Qt.darker(art.tint, 2.05)
                startX: 0; startY: art.height * 0.66
                PathCubic {
                    control1X: art.width * 0.3; control1Y: art.height * 0.48
                    control2X: art.width * 0.65; control2Y: art.height * (0.83 - art.waveOffset * 0.16)
                    x: art.width; y: art.height * 0.62
                }
                PathLine { x: art.width; y: art.height - art.radius }
                PathQuad { x: art.width - art.radius; y: art.height; controlX: art.width; controlY: art.height }
                PathLine { x: art.radius; y: art.height }
                PathQuad { x: 0; y: art.height - art.radius; controlX: 0; controlY: art.height }
                PathLine { x: 0; y: art.height * 0.66 }
            }
            ShapePath {
                strokeColor: "transparent"
                fillColor: Qt.darker(art.tint, 1.65)
                startX: 0; startY: art.height * 0.8
                PathCubic {
                    control1X: art.width * 0.38; control1Y: art.height * (0.94 - art.waveOffset * 0.18)
                    control2X: art.width * 0.74; control2Y: art.height * 0.68
                    x: art.width; y: art.height * 0.77
                }
                PathLine { x: art.width; y: art.height - art.radius }
                PathQuad { x: art.width - art.radius; y: art.height; controlX: art.width; controlY: art.height }
                PathLine { x: art.radius; y: art.height }
                PathQuad { x: 0; y: art.height - art.radius; controlX: 0; controlY: art.height }
                PathLine { x: 0; y: art.height * 0.8 }
            }
        }
        Rectangle {
            width: Math.min(art.width * 0.48, art.height * 0.56)
            height: width
            x: art.width - width * 0.9
            y: art.height * (0.08 + art.waveOffset * 0.1)
            rotation: 45
            radius: width * 0.14
            color: "transparent"
            border.color: Qt.rgba(art.tint.r, art.tint.g, art.tint.b, 0.38)
            Rectangle {
                anchors.fill: parent
                anchors.margins: 14
                radius: parent.radius * 0.6
                color: "transparent"
                border.color: Qt.rgba(art.tint.r, art.tint.g, art.tint.b, 0.24)
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 6
        visible: Colors.decoFrames
        radius: 8
        color: "transparent"
        border.color: Qt.rgba(Colors.brass.r, Colors.brass.g, Colors.brass.b, 0.3)
    }
}
