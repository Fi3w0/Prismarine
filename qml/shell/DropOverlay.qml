import QtQuick
import QtQuick.Layouts

// Shown while files are dragged over the window; purely visual, never takes input.
Item {
    id: overlay
    property bool active: false
    property string targetName: ""
    anchors.fill: parent
    opacity: active ? 1 : 0
    visible: opacity > 0
    Behavior on opacity { NumberAnimation { duration: Colors.animations ? 140 : 0 } }
    Rectangle {
        anchors.fill: parent
        color: Colors.light ? Qt.rgba(0.93, 0.95, 0.93, 0.55) : Qt.rgba(0.02, 0.05, 0.07, 0.55)
    }
    Rectangle {
        anchors { fill: parent; margins: 18 }
        radius: 20
        color: "transparent"
        border.width: 2
        border.color: Colors.accent
        opacity: 0.8
    }
    Rectangle {
        anchors { horizontalCenter: parent.horizontalCenter; bottom: parent.bottom; bottomMargin: 48 }
        width: Math.min(parent.width - 96, card.implicitWidth + 56)
        height: card.implicitHeight + 36
        radius: 16
        color: Colors.surface
        border.color: Colors.accent
        ColumnLayout {
            id: card
            anchors.centerIn: parent
            width: parent.width - 56
            spacing: 6
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: "Drop to install"
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: 24
                font.letterSpacing: 1
            }
            Text {
                Layout.fillWidth: true
                horizontalAlignment: Text.AlignHCenter
                text: (overlay.targetName ? "Mods, resource packs, shaders and datapacks go to " + overlay.targetName + ". " : "")
                      + "Modpacks (.mrpack or .zip) become new instances. Drop on a card to choose its instance."
                color: Colors.subtext
                font.pixelSize: 13
                wrapMode: Text.Wrap
            }
        }
    }
}
