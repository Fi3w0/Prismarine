import QtQuick
import QtQuick.Shapes

// Static waves behind the pages. Nothing here animates, so it costs no idle frames.
Item {
    id: decor
    enabled: false
    Accessible.ignored: true
    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        opacity: Colors.light ? 0.22 : 0.16
        ShapePath {
            strokeColor: "transparent"
            fillColor: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.22)
            startX: 0
            startY: decor.height - 70
            PathCubic {
                control1X: decor.width * 0.3
                control1Y: decor.height - 12
                control2X: decor.width * 0.62
                control2Y: decor.height - 130
                x: decor.width
                y: decor.height - 60
            }
            PathLine { x: decor.width; y: decor.height }
            PathLine { x: 0; y: decor.height }
            PathLine { x: 0; y: decor.height - 70 }
        }
        ShapePath {
            strokeColor: Colors.accent
            strokeWidth: 1
            fillColor: "transparent"
            startX: 0
            startY: decor.height - 130
            PathCubic {
                control1X: decor.width * 0.34
                control1Y: decor.height - 70
                control2X: decor.width * 0.58
                control2Y: decor.height - 210
                x: decor.width
                y: decor.height - 110
            }
        }
    }
}
