import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

MotionDialog {
    id: dialog
    objectName: "curseForgeKeyDialog"
    required property var catalog
    title: "CurseForge API key"
    width: 480
    modal: true
    standardButtons: Dialog.Cancel
    onClosed: key.text = ""
    background: Rectangle { color: Colors.surface; radius: 12; border.color: Colors.border }
    contentItem: ColumnLayout {
        spacing: 14
        Text {
            Layout.fillWidth: true; wrapMode: Text.Wrap; color: Colors.subtext
            text: "Browsing CurseForge inside Prismarine requires an API key. Enter your project key here; it is only sent to CurseForge. You can also install through Prism Launcher without adding a key here."
        }
        TextLink { text: "Get a key from CurseForge"; onClicked: Qt.openUrlExternally("https://console.curseforge.com/") }
        InputField { id: key; Layout.fillWidth: true; echoMode: TextInput.Password; placeholderText: "CurseForge API key" }
        ToggleSwitch { id: remember; text: "Remember in the system keyring"; checked: true }
        RowLayout {
            ActionButton { text: "Clear key"; enabled: dialog.catalog.curseForgeReady; onClicked: { dialog.catalog.setCurseForgeKey("", true); dialog.accept(); } }
            Item { Layout.fillWidth: true }
            ActionButton { text: "Use key"; primary: true; enabled: !!key.text.trim(); onClicked: { dialog.catalog.setCurseForgeKey(key.text, remember.checked); dialog.accept(); } }
        }
    }
}
