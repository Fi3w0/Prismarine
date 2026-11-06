import QtQuick
import QtQuick.Controls

ComboBox {
    id: control
    implicitHeight: 40
    implicitWidth: 160
    font.pixelSize: Typography.control
    padding: 10
    rightPadding: 30
    contentItem: Text {
        text: control.displayText
        font: control.font
        color: Colors.text
        verticalAlignment: Text.AlignVCenter
        elide: Text.ElideRight
    }
    indicator: Canvas {
        readonly property color stroke: Colors.subtext
        onStrokeChanged: requestPaint()
        x: control.width - width - 12
        y: (control.height - height) / 2
        width: 10
        height: 6
        onPaint: {
            const ctx = getContext("2d");
            ctx.reset();
            ctx.strokeStyle = stroke;
            ctx.lineWidth = 1.5;
            ctx.beginPath();
            ctx.moveTo(1, 1);
            ctx.lineTo(5, 5);
            ctx.lineTo(9, 1);
            ctx.stroke();
        }
    }
    background: Rectangle {
        radius: Colors.controlRadius
        color: Colors.surfaceHi
        border.color: control.visualFocus ? Colors.accent : Colors.outline
    }
    delegate: ItemDelegate {
        required property int index
        width: control.width - 8
        height: 40
        highlighted: control.highlightedIndex === index
        contentItem: Text {
            text: control.textAt(index)
            color: Colors.text
            font: control.font
            verticalAlignment: Text.AlignVCenter
            elide: Text.ElideRight
        }
        background: Rectangle {
            radius: 6
            color: parent.highlighted ? Colors.surfaceHi : Colors.surface
        }
    }
    popup: Popup {
        y: control.height + 4
        width: control.width
        implicitHeight: Math.min(contentItem.implicitHeight + 8, 320)
        padding: 4
        background: Rectangle {
            color: Colors.surface
            radius: Colors.controlRadius
            border.color: Colors.border
        }
        contentItem: ListView {
            clip: true
            implicitHeight: contentHeight
            model: control.popup.visible ? control.delegateModel : null
            currentIndex: control.highlightedIndex
            ScrollBar.vertical: ScrollBar {}
        }
    }
}
