import QtQuick
import QtQuick.Shapes
import QtQuick.Effects

Rectangle {
    id: backdrop
    property string cover: ""
    property string screenshot: ""
    property bool showScreenshot: false
    readonly property bool hasImage: image.status === Image.Ready
    color: Colors.hero
    clip: true
    Image {
        id: image
        anchors.fill: parent
        source: backdrop.cover || (backdrop.showScreenshot ? backdrop.screenshot : "")
        fillMode: Image.PreserveAspectCrop
        visible: false
        asynchronous: true
        sourceSize.width: 1600
    }
    MultiEffect {
        anchors.fill: parent
        source: image
        visible: image.status === Image.Ready
        blurEnabled: true
        blur: 0.35
        brightness: -0.4
    }
    Rectangle {
        anchors.fill: parent
        color: image.status === Image.Ready ? (Colors.light ? "#88eef1ee" : "#660a1016") : "transparent"
    }
    Rectangle {
        visible: !backdrop.hasImage
        width: 146
        height: width
        rotation: 45
        x: backdrop.width - 260
        y: 28
        color: "transparent"
        border.color: Colors.accent
        opacity: 0.24
        Rectangle {
            anchors.centerIn: parent
            width: 78
            height: width
            color: "transparent"
            border.color: Colors.accent
        }
    }
    Shape {
        visible: !backdrop.hasImage
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        opacity: 0.3
        ShapePath {
            strokeColor: Colors.accent
            strokeWidth: 1.2
            fillColor: "transparent"
            startX: 0
            startY: backdrop.height - 48
            PathCubic {
                control1X: backdrop.width * 0.3
                control1Y: backdrop.height + 5
                control2X: backdrop.width * 0.56
                control2Y: backdrop.height - 100
                x: backdrop.width
                y: backdrop.height - 34
            }
        }
        ShapePath {
            strokeColor: Colors.accent
            strokeWidth: 1.2
            fillColor: "transparent"
            startX: 0
            startY: backdrop.height - 26
            PathCubic {
                control1X: backdrop.width * 0.3
                control1Y: backdrop.height + 28
                control2X: backdrop.width * 0.56
                control2Y: backdrop.height - 78
                x: backdrop.width
                y: backdrop.height - 12
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 12
        color: "transparent"
        border.color: Colors.heroLine
        visible: Colors.decoFrames && !backdrop.hasImage
    }
}
