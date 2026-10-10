import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info
    property real panelWidth: width

    Layout.preferredHeight: 188
    radius: 12
    color: Colors.surface
    border.color: Colors.border
    ColumnLayout {
        anchors {
            fill: parent
            margins: 20
        }
        spacing: 10
        Text {
            text: "Notes"
            font.family: Colors.displayFont
            font.pixelSize: 20
            font.letterSpacing: 2
            color: Colors.bone
        }
        Text {
            text: "Private notes for this instance"
            font.pixelSize: 12
            color: Colors.subtext
        }
        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            TextArea {
                id: notes
                objectName: "instanceNotes"
                text: controller.preferences.notes[contents.instanceId] || ""
                placeholderText: "Write something to remember…"
                color: Colors.text
                placeholderTextColor: Colors.subtext
                wrapMode: TextEdit.Wrap
                font.pixelSize: 13
                background: Rectangle {
                    radius: 8
                    color: Colors.mantle
                    border.color: notes.activeFocus ? Colors.accent : Colors.border
                }
                onTextChanged: if (!contents.loading)
                    controller.preferences.setNote(contents.instanceId, text)
            }
        }
    }
}
