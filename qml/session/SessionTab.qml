import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One tab on the Playing page: a game or All games.
Rectangle {
    required property var page
    id: chip
    property string key
    property string label
    property string sub
    property bool live: true
    property bool closable: false
    readonly property bool selected: page.current === key
    signal closeRequested
    implicitWidth: Math.min(260, openButton.implicitWidth + (closable ? closeButton.width : 0))
    implicitHeight: 40
    radius: 10
    color: selected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16) : chipHover.hovered ? Colors.inset : Colors.surface
    border.width: openButton.visualFocus ? 2 : 1
    border.color: selected || openButton.visualFocus ? Colors.accent : Colors.border
    HoverHandler { id: chipHover; cursorShape: Qt.PointingHandCursor }
    AbstractButton {
        id: openButton
        anchors { left: parent.left; top: parent.top; bottom: parent.bottom; right: chip.closable ? closeButton.left : parent.right }
        leftPadding: 14
        rightPadding: chip.closable ? 4 : 14
        Accessible.name: chip.label
        onClicked: page.tab = chip.key
        background: Item {}
        contentItem: RowLayout {
            spacing: 8
            Rectangle {
                implicitWidth: 8
                implicitHeight: 8
                radius: 4
                color: chip.live ? Colors.accent : Colors.subtext
                visible: chip.key !== "all"
            }
            Text {
                Layout.fillWidth: true
                text: chip.label
                color: chip.selected ? Colors.text : Colors.subtext
                font.pixelSize: Typography.body
                font.weight: chip.selected ? Font.DemiBold : Font.Normal
                elide: Text.ElideRight
            }
            Text {
                visible: !!chip.sub
                text: chip.sub
                color: Colors.subtext
                font.pixelSize: Typography.caption
            }
        }
    }
    AbstractButton {
        id: closeButton
        visible: chip.closable
        anchors { right: parent.right; top: parent.top; bottom: parent.bottom }
        width: 30
        Accessible.name: qsTr("Close %1").arg(chip.label)
        onClicked: chip.closeRequested()
        background: Rectangle {
            anchors.margins: 4
            anchors.fill: parent
            radius: 7
            color: closeButton.hovered ? Colors.surfaceHi : "transparent"
            border.color: closeButton.visualFocus ? Colors.accent : "transparent"
        }
        contentItem: Text {
            text: "✕"
            color: Colors.subtext
            font.pixelSize: Typography.caption
            horizontalAlignment: Text.AlignHCenter
            verticalAlignment: Text.AlignVCenter
        }
    }
}
