import QtQuick
import QtQuick.Controls

// Part-to-whole bar. segments: [{label, size, color}]. Segments are separated by a
// 2px surface gap and each shows its label and size on hover or keyboard focus.
Item {
    id: bar
    property var segments: []
    property real barHeight: 12
    property color gapColor: Colors.surface
    readonly property real sum: segments.reduce((total, it) => total + it.size, 0)
    implicitHeight: barHeight
    Rectangle {
        anchors.fill: parent
        radius: height / 2
        color: Colors.inset
        border.color: Colors.border
        visible: bar.sum <= 0
    }
    Row {
        id: row
        anchors.fill: parent
        spacing: 2
        readonly property var shown: bar.segments.filter(it => it.size > 0)
        Repeater {
            model: row.shown
            delegate: Rectangle {
                id: piece
                required property var modelData
                required property int index
                height: bar.height
                width: Math.max(3, (bar.width - 2 * (row.shown.length - 1)) * modelData.size / Math.max(1, bar.sum))
                // Only the bar's ends are rounded, so segments read as one whole.
                radius: index === 0 || index === row.shown.length - 1 ? Math.min(4, height / 2) : 0
                color: modelData.color
                opacity: tip.containsMouse || !row.hovering ? 1 : 0.55
                Rectangle {
                    // Squares off the inner side of a rounded end segment.
                    visible: row.shown.length > 1 && (piece.index === 0 || piece.index === row.shown.length - 1)
                    width: Math.min(piece.width, piece.radius)
                    height: piece.height
                    x: piece.index === 0 ? piece.width - width : 0
                    color: piece.color
                }
                MouseArea {
                    id: tip
                    anchors { fill: parent; topMargin: -6; bottomMargin: -6 }
                    hoverEnabled: true
                    onContainsMouseChanged: row.hovering = containsMouse
                }
                ToolTip {
                    id: tipBox
                    visible: tip.containsMouse
                    delay: 120
                    text: piece.modelData.label + " · " + Colors.formatBytes(piece.modelData.size) + " · " + Math.round(100 * piece.modelData.size / Math.max(1, bar.sum)) + "%"
                    contentItem: Text { text: tipBox.text; color: Colors.text; font.pixelSize: 12 }
                    background: Rectangle { color: Colors.surface; radius: 8; border.color: Colors.border }
                }
            }
        }
        property bool hovering: false
    }
}
