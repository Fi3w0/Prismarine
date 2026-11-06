import QtQuick
import QtQuick.Layouts

Rectangle {
    id: banner
    required property string title
    property string detail: ""
    Layout.fillWidth: true
    implicitHeight: 128
    radius: 20
    gradient: Gradient {
        orientation: Gradient.Horizontal
        GradientStop { position: 0; color: Colors.light ? "#cce6de" : "#1a3e45" }
        GradientStop { position: 0.65; color: Colors.surface }
        GradientStop { position: 1; color: Colors.surfaceHi }
    }
    Canvas {
        id: pattern
        anchors.fill: parent
        opacity: 0.35
        readonly property color dots: Colors.heroLine
        readonly property color lines: Colors.outline
        onDotsChanged: requestPaint()
        onLinesChanged: requestPaint()
        onWidthChanged: requestPaint()
        onHeightChanged: requestPaint()
        onPaint: {
            const ctx = getContext("2d"); ctx.reset();
            ctx.fillStyle = dots;
            for (let x = width * 0.58; x < width - 10; x += 22)
                for (let y = 16; y < height - 10; y += 22) { ctx.beginPath(); ctx.arc(x, y, 1, 0, Math.PI * 2); ctx.fill(); }
            ctx.strokeStyle = lines; ctx.lineWidth = 1;
            for (let i = 0; i < 3; ++i) {
                ctx.beginPath(); ctx.moveTo(width * 0.55, 78 + i * 16);
                ctx.bezierCurveTo(width * 0.72, 22 + i * 16, width * 0.84, 105 + i * 16, width, 60 + i * 16); ctx.stroke();
            }
            const cx = width - 110, cy = 45;
            ctx.beginPath(); ctx.moveTo(cx, cy - 30); ctx.lineTo(cx + 30, cy); ctx.lineTo(cx, cy + 30); ctx.lineTo(cx - 30, cy); ctx.closePath(); ctx.stroke();
        }
    }
    Column {
        anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 28 }
        spacing: 8
        Text { width: parent.width; text: banner.title; color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: Typography.heroCompact; elide: Text.ElideRight }
        Text { width: parent.width; text: banner.detail; color: Colors.subtext; font.pixelSize: Typography.body; wrapMode: Text.Wrap }
    }
}
