import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Asks for one line of text. The caller connects to `submitted` and closes the
// dialog itself when the value is accepted, so errors can be shown in place.
MotionDialog {
    id: dialog
    property string placeholder: ""
    property string confirmText: "Save"
    property string error: ""
    property alias text: field.text
    signal submitted(string value)
    function ask(initial) {
        field.text = initial || "";
        error = "";
        open();
    }
    width: 440
    modal: true
    onOpened: { field.forceActiveFocus(); field.selectAll(); }
    contentItem: ColumnLayout {
        spacing: 10
        InputField {
            id: field
            objectName: "promptInput"
            Layout.fillWidth: true
            placeholderText: dialog.placeholder
            Accessible.name: dialog.placeholder
            maximumLength: 80
            onTextEdited: dialog.error = ""
            onAccepted: if (text.trim()) dialog.submitted(text.trim())
        }
        Text {
            Layout.fillWidth: true
            visible: !!dialog.error
            text: dialog.error
            textFormat: Text.PlainText
            color: Colors.danger
            wrapMode: Text.Wrap
        }
    }
    footer: DialogActions {
        confirmName: "promptConfirm"
        confirmText: dialog.confirmText
        confirmWidth: 130
        confirmEnabled: !!field.text.trim()
        onCancelled: dialog.close()
        onConfirmed: dialog.submitted(field.text.trim())
    }
}
