import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Every dialog's frame: themed title, optional subtitle, close button and button row.
// Dialogs that need something else still override header, footer or background.
Dialog {
    id: control
    property string subtitle: ""
    property bool showClose: true
    padding: 24
    topPadding: header && header.visible ? 4 : 24
    bottomPadding: 20
    Overlay.modal: Rectangle {
        color: Colors.light ? Qt.rgba(0.08, 0.14, 0.17, 0.32) : Qt.rgba(0.01, 0.03, 0.05, 0.62)
        Behavior on opacity { NumberAnimation { duration: Colors.animations ? 180 : 0 } }
    }
    background: Rectangle {
        color: Colors.surface
        radius: 16
        border.color: Colors.border
        // A thin accent line ties dialogs to the rest of the deep-sea chrome.
        Rectangle {
            anchors { top: parent.top; left: parent.left; right: parent.right; leftMargin: 24; rightMargin: 24 }
            height: 2
            radius: 1
            color: Colors.accent
            opacity: 0.55
        }
    }
    header: Item {
        visible: !!control.title
        implicitHeight: titles.implicitHeight + 40
        ColumnLayout {
            id: titles
            anchors { left: parent.left; right: parent.right; top: parent.top; leftMargin: 24; rightMargin: 64; topMargin: 24 }
            spacing: 4
            Text {
                Layout.fillWidth: true
                text: control.title
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: 24
                font.letterSpacing: 1
                elide: Text.ElideRight
            }
            Text {
                Layout.fillWidth: true
                visible: !!control.subtitle
                text: control.subtitle
                color: Colors.subtext
                font.pixelSize: 13
                wrapMode: Text.Wrap
                lineHeight: 1.2
            }
        }
        ToolButton {
            visible: control.showClose && control.closePolicy !== Popup.NoAutoClose
            anchors { right: parent.right; top: parent.top; rightMargin: 16; topMargin: 18 }
            width: 34
            height: 34
            Accessible.name: "Close"
            onClicked: control.reject()
            background: Rectangle { radius: 17; color: parent.hovered ? Colors.surfaceHi : "transparent" }
            contentItem: LineIcon { name: "close"; tint: Colors.subtext; implicitWidth: 16; implicitHeight: 16 }
        }
    }
    footer: DialogButtonBox {
        visible: count > 0
        alignment: Qt.AlignRight
        spacing: 10
        leftPadding: 24
        rightPadding: 24
        topPadding: 0
        bottomPadding: 22
        background: Item {}
        delegate: ActionButton {
            implicitWidth: Math.max(110, contentItem.implicitWidth + 36)
            primary: DialogButtonBox.buttonRole === DialogButtonBox.AcceptRole || DialogButtonBox.buttonRole === DialogButtonBox.YesRole
        }
    }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Colors.animations ? 240 : 0; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.96; to: 1; duration: Colors.animations ? 320 : 0; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; to: 0; duration: Colors.animations ? 180 : 0; easing.type: Easing.InCubic }
            NumberAnimation { property: "scale"; to: 0.98; duration: Colors.animations ? 180 : 0 }
        }
    }
}
