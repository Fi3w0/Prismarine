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
    // Waves stay in the bottom 28 px so they never cross text placed above them.
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
            startY: backdrop.height - 24
            PathCubic {
                control1X: backdrop.width * 0.3
                control1Y: backdrop.height + 2
                control2X: backdrop.width * 0.56
                control2Y: backdrop.height - 44
                x: backdrop.width
                y: backdrop.height - 18
            }
        }
        ShapePath {
            strokeColor: Colors.accent
            strokeWidth: 1.2
            fillColor: "transparent"
            startX: 0
            startY: backdrop.height - 10
            PathCubic {
                control1X: backdrop.width * 0.3
                control1Y: backdrop.height + 14
                control2X: backdrop.width * 0.56
                control2Y: backdrop.height - 36
                x: backdrop.width
                y: backdrop.height - 4
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
