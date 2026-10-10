import QtQuick
import QtQuick.Controls

// Accepts files dragged from the desktop onto one instance (a card, row or sidebar entry).
DropArea {
    id: target
    property string label: ""
    property real radius: 12
    signal filesDropped(var urls)
    anchors.fill: parent
    keys: ["text/uri-list"]
    onEntered: drag => { if (!drag.hasUrls) drag.accepted = false; }
    onDropped: drop => {
        if (!drop.hasUrls) return;
        drop.acceptProposedAction();
        target.filesDropped(drop.urls);
    }
    Rectangle {
        anchors.fill: parent
        visible: target.containsDrag
        radius: target.radius
        color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.18)
        border.width: 2
        border.color: Colors.accent
        Rectangle {
            visible: !!target.label && parent.height >= 48
            anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 10 }
            width: Math.min(parent.width - 16, hint.implicitWidth + 20)
            height: 26
            radius: 13
            color: Colors.accent
            Text {
                id: hint
                anchors.centerIn: parent
                width: parent.width - 20
                horizontalAlignment: Text.AlignHCenter
                text: "Add to " + target.label
                color: Colors.accentInk
                font.pixelSize: 12
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
        }
    }
}
