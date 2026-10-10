import QtQuick
import QtQuick.Controls

Button {
    id: chip
    property color tint: Colors.subtext
    property bool active: false
    property bool interactive: false
    focusPolicy: interactive ? Qt.StrongFocus : Qt.NoFocus
    enabled: interactive
    implicitWidth: label.implicitWidth + 22
    implicitHeight: 28
    padding: 0
    background: Rectangle {
        radius: height / 2
        color: Qt.rgba(chip.tint.r, chip.tint.g, chip.tint.b, chip.active ? 0.28 : chip.hovered ? 0.18 : 0.12)
        border.width: 1
        border.color: chip.visualFocus ? Colors.accent : Qt.rgba(chip.tint.r, chip.tint.g, chip.tint.b, chip.active ? 0.8 : 0.32)
        Behavior on color {
            ColorAnimation {
                duration: Colors.animations ? 120 : 0
            }
        }
    }
    contentItem: Text {
        id: label
        text: chip.text
        color: chip.tint
        font.pixelSize: 13
        font.weight: Font.DemiBold
        horizontalAlignment: Text.AlignHCenter
        verticalAlignment: Text.AlignVCenter
    }
    HoverHandler {
        cursorShape: chip.interactive ? Qt.PointingHandCursor : Qt.ArrowCursor
    }
}
