import QtQuick
import QtQuick.Layouts

// A history of samples (memory, CPU or GPU load) as a filled line.
Canvas {
    id: graph
    required property var samples
    property real ceiling: 0
    property color tint: Colors.accent
    onTintChanged: requestPaint()
    Layout.fillWidth: true
    Layout.preferredHeight: 50
    onSamplesChanged: requestPaint()
    onWidthChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        if (samples.length < 2)
            return;
        const top = Math.max(ceiling, Math.max(...samples) * 1.15, 1);
        const step = width / (samples.length - 1);
        const y = value => height - 2 - (value / top) * (height - 4);
        ctx.beginPath();
        ctx.moveTo(0, y(samples[0]));
        for (let i = 1; i < samples.length; ++i)
            ctx.lineTo(i * step, y(samples[i]));
        ctx.strokeStyle = tint;
        ctx.lineWidth = 2;
        ctx.stroke();
        ctx.lineTo(width, height);
        ctx.lineTo(0, height);
        ctx.closePath();
        ctx.fillStyle = Qt.rgba(tint.r, tint.g, tint.b, 0.16);
        ctx.fill();
    }
}
