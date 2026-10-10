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
    radius: 12
    color: Qt.darker(tint, 3.7)
    clip: true
    Image {
        id: shot
        anchors.fill: parent
        source: art.cover || (art.showScreenshot ? art.screenshot : "")
        sourceSize.width: 600
        fillMode: Image.PreserveAspectCrop
        asynchronous: true
        visible: false
    }
    Rectangle {
        id: mask
        anchors.fill: parent
        radius: art.radius
        visible: false
        layer.enabled: true
    }
    MultiEffect {
        anchors.fill: parent
        source: shot
        visible: shot.status === Image.Ready
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
        visible: shot.status !== Image.Ready
        Rectangle {
            width: Math.min(art.width * 0.3, art.height * 0.32)
            height: width
            x: (art.width - width) / 2
            y: art.height * 0.29 - height / 2
            rotation: 45
            color: "transparent"
            border.width: 1.5
            border.color: art.tint
            opacity: 0.6
            Rectangle {
                anchors.centerIn: parent
                width: parent.width * 0.55
                height: width
                color: "transparent"
                border.width: 1.5
                border.color: art.tint
            }
        }
        Shape {
            anchors.fill: parent
            layer.enabled: true
            layer.samples: 4
            opacity: 0.55
            ShapePath {
                fillColor: "transparent"
                strokeColor: art.tint
                strokeWidth: 1.6
                startX: 0
                startY: art.height * 0.72
                PathCubic {
                    control1X: art.width * 0.45
                    control1Y: art.height * 0.57
                    control2X: art.width * 0.55
                    control2Y: art.height * 0.87
                    x: art.width
                    y: art.height * 0.72
                }
            }
            ShapePath {
                fillColor: "transparent"
                strokeColor: art.tint
                strokeWidth: 1
                startX: 0
                startY: art.height * 0.77
                PathCubic {
                    control1X: art.width * 0.45
                    control1Y: art.height * 0.62
                    control2X: art.width * 0.55
                    control2Y: art.height * 0.92
                    x: art.width
                    y: art.height * 0.77
                }
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
