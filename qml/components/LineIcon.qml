import QtQuick

Canvas {
    id: icon
    property string name: "library"
    property color tint: Colors.subtext
    implicitWidth: 22
    implicitHeight: 22
    onNameChanged: requestPaint()
    onTintChanged: requestPaint()
    onWidthChanged: requestPaint()
    onHeightChanged: requestPaint()
    onPaint: {
        const ctx = getContext("2d");
        ctx.reset();
        ctx.scale(width / 24, height / 24);
        ctx.strokeStyle = tint;
        ctx.fillStyle = tint;
        ctx.lineWidth = 1.7;
        ctx.lineCap = "round";
        ctx.lineJoin = "round";
        ctx.beginPath();
        switch (name) {
        case "home":
            ctx.moveTo(3, 11);
            ctx.lineTo(12, 4);
            ctx.lineTo(21, 11);
            ctx.moveTo(5, 10);
            ctx.lineTo(5, 21);
            ctx.lineTo(19, 21);
            ctx.lineTo(19, 10);
            break;
        case "library":
            ctx.rect(3, 3, 7, 7);
            ctx.rect(14, 3, 7, 7);
            ctx.rect(3, 14, 7, 7);
            ctx.rect(14, 14, 7, 7);
            break;
        case "list":
            ctx.moveTo(4, 6);
            ctx.lineTo(20, 6);
            ctx.moveTo(4, 12);
            ctx.lineTo(20, 12);
            ctx.moveTo(4, 18);
            ctx.lineTo(20, 18);
            break;
        case "plus":
            ctx.moveTo(12, 5);
            ctx.lineTo(12, 19);
            ctx.moveTo(5, 12);
            ctx.lineTo(19, 12);
            break;
        case "settings":
            for (let i = 0; i < 48; ++i) {
                const a = i * Math.PI / 24 - Math.PI / 2;
                const r = i % 8 < 4 ? 10 : 7.8;
                if (i === 0) ctx.moveTo(12 + r * Math.cos(a), 12 + r * Math.sin(a));
                else ctx.lineTo(12 + r * Math.cos(a), 12 + r * Math.sin(a));
            }
            ctx.closePath();
            ctx.moveTo(15, 12); ctx.arc(12, 12, 3, 0, Math.PI * 2);
            break;
        case "accounts":
            ctx.arc(12, 7, 4, 0, Math.PI * 2);
            ctx.moveTo(4, 21);
            ctx.bezierCurveTo(4, 12, 20, 12, 20, 21);
            break;
        case "browse":
            ctx.arc(12, 12, 9, 0, Math.PI * 2);
            ctx.moveTo(16, 8);
            ctx.lineTo(13, 13);
            ctx.lineTo(8, 16);
            ctx.lineTo(11, 11);
            ctx.closePath();
            break;
        case "refresh":
            ctx.arc(12, 12, 8, Math.PI * 0.2, Math.PI * 1.85);
            ctx.moveTo(19.1, 3.3); ctx.lineTo(19.1, 8.4); ctx.lineTo(14, 8.4);
            break;
        case "package":
            ctx.moveTo(3, 7); ctx.lineTo(12, 3); ctx.lineTo(21, 7); ctx.lineTo(21, 17); ctx.lineTo(12, 21); ctx.lineTo(3, 17); ctx.closePath();
            ctx.moveTo(3, 7); ctx.lineTo(12, 11); ctx.lineTo(21, 7);
            ctx.moveTo(12, 11); ctx.lineTo(12, 21);
            ctx.moveTo(7.5, 5); ctx.lineTo(16.5, 9);
            break;
        case "world":
            ctx.arc(12, 12, 9, 0, Math.PI * 2);
            ctx.moveTo(3, 12); ctx.lineTo(21, 12);
            ctx.moveTo(12, 3); ctx.bezierCurveTo(4, 10, 9, 20, 12, 21); ctx.bezierCurveTo(20, 14, 15, 4, 12, 3);
            break;
        case "shaders":
            ctx.moveTo(12, 2); ctx.lineTo(15, 9); ctx.lineTo(22, 12); ctx.lineTo(15, 15); ctx.lineTo(12, 22); ctx.lineTo(9, 15); ctx.lineTo(2, 12); ctx.lineTo(9, 9); ctx.closePath();
            break;
        case "external":
            ctx.moveTo(14, 3);
            ctx.lineTo(21, 3);
            ctx.lineTo(21, 10);
            ctx.moveTo(21, 3);
            ctx.lineTo(10, 14);
            ctx.moveTo(9, 4);
            ctx.lineTo(4, 4);
            ctx.lineTo(4, 20);
            ctx.lineTo(20, 20);
            ctx.lineTo(20, 15);
            break;
        case "back":
            ctx.moveTo(13, 5);
            ctx.lineTo(6, 12);
            ctx.lineTo(13, 19);
            ctx.moveTo(6, 12);
            ctx.lineTo(21, 12);
            break;
        case "folder":
            ctx.moveTo(3, 6);
            ctx.lineTo(10, 6);
            ctx.lineTo(12, 9);
            ctx.lineTo(21, 9);
            ctx.lineTo(21, 20);
            ctx.lineTo(3, 20);
            ctx.closePath();
            break;
        case "edit":
            ctx.moveTo(4, 20); ctx.lineTo(5, 15); ctx.lineTo(16, 4);
            ctx.lineTo(20, 8); ctx.lineTo(9, 19); ctx.closePath();
            ctx.moveTo(14, 6); ctx.lineTo(18, 10);
            break;
        case "play":
            ctx.moveTo(7, 4);
            ctx.lineTo(20, 12);
            ctx.lineTo(7, 20);
            ctx.closePath();
            ctx.fill();
            return;
        case "close":
            ctx.moveTo(6, 6);
            ctx.lineTo(18, 18);
            ctx.moveTo(18, 6);
            ctx.lineTo(6, 18);
            break;
        case "search":
            ctx.arc(10.5, 10.5, 6.5, 0, Math.PI * 2);
            ctx.moveTo(15.3, 15.3);
            ctx.lineTo(20.5, 20.5);
            break;
        case "star":
            for (let i = 0; i < 10; i++) {
                const a = -Math.PI / 2 + i * Math.PI / 5, r = i % 2 ? 4 : 9;
                if (i === 0)
                    ctx.moveTo(12 + r * Math.cos(a), 12 + r * Math.sin(a));
                else
                    ctx.lineTo(12 + r * Math.cos(a), 12 + r * Math.sin(a));
            }
            ctx.closePath();
            break;
        }
        ctx.stroke();
    }
}
