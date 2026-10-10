import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// A themed yes/no question; emits confirmed() only for the confirm button.
MotionDialog {
    id: dialog
    property string message: ""
    property string confirmText: "Confirm"
    property bool danger: false
    signal confirmed
    modal: true
    width: 460
    padding: 22
    background: Rectangle {
        radius: 14
        color: Colors.surface
        border.color: Colors.border
    }
    header: Text {
        text: dialog.title
        color: Colors.bone
        font.family: Colors.displayFont
        font.pixelSize: 20
        font.letterSpacing: 1
        padding: 22
        bottomPadding: 0
        wrapMode: Text.Wrap
    }
    contentItem: Text {
        text: dialog.message
        color: Colors.subtext
        font.pixelSize: 13
        lineHeight: 1.25
        wrapMode: Text.Wrap
    }
    footer: Item {
        implicitHeight: 64
        RowLayout {
            anchors {
                fill: parent
                leftMargin: 22
                rightMargin: 22
                bottomMargin: 18
            }
            spacing: 10
            Item {
                Layout.fillWidth: true
            }
            ActionButton {
                text: "Cancel"
                implicitWidth: 100
                onClicked: dialog.reject()
            }
            ActionButton {
                objectName: "confirmButton"
                text: dialog.confirmText
                implicitWidth: 130
                primary: !dialog.danger
                danger: dialog.danger
                onClicked: {
                    dialog.accept();
                    dialog.confirmed();
                }
            }
        }
    }
}
