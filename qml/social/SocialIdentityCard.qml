import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: panel
    required property var controller
    readonly property var social: controller.social
    readonly property var links: social ? social.accounts : []
    readonly property var profiles: controller.instances.accounts.filter(a => a.type === "MSA")
    implicitHeight: body.implicitHeight + 40
    color: Colors.surface; radius: 14; border.color: Colors.border
    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 12
        Text { text: "Your Prismarine identity"; font.family: Colors.displayFont; font.pixelSize: 22; color: Colors.bone }
        Text {
            Layout.fillWidth: true
            text: panel.social && panel.social.exists ? panel.social.name : "Keep your friends together across Minecraft accounts."
            textFormat: Text.PlainText; color: Colors.text; font.pixelSize: 15; wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            visible: !!panel.social && !panel.social.ready
            text: panel.social && !panel.social.available ? "This build needs QtKeychain for secure identity storage. Your Minecraft library still works normally." : "Your private identity key is kept in your system keyring. Unlocking is local; there is no Prismarine password or server."
            color: Colors.subtext; font.pixelSize: 13; wrapMode: Text.Wrap
        }
        InputField {
            id: identityName
            objectName: "socialIdentityName"
            Layout.fillWidth: true
            visible: !!panel.social && !panel.social.exists
            placeholderText: "Your display name"
            maximumLength: 64
            Accessible.name: "Prismarine display name"
        }
        ActionButton {
            objectName: "socialUnlockButton"
            visible: !!panel.social && !panel.social.ready
            enabled: !!panel.social && panel.social.available && !panel.social.busy && (panel.social.exists || identityName.text.trim().length > 0)
            text: panel.social && panel.social.busy ? "Opening keyring…" : panel.social && panel.social.exists ? "Unlock identity" : "Create local identity"
            implicitWidth: contentItem.implicitWidth + 32
            primary: true
            onClicked: panel.social.unlock(identityName.text)
        }
        Text {
            Layout.fillWidth: true
            visible: !!panel.social && panel.social.exists
            text: panel.social ? panel.social.fingerprint : ""
            font.family: "monospace"; font.pixelSize: 12; color: Colors.accent; wrapMode: Text.WrapAnywhere
        }
        RowLayout {
            visible: !!panel.social && panel.social.ready
            spacing: 12
            ActionButton { text: "Export friend card"; implicitWidth: contentItem.implicitWidth + 32; enabled: !!panel.social && !panel.social.busy; onClicked: saveCard.open() }
            TextLink { text: "Lock"; onClicked: panel.social.lock() }
        }
        Text {
            Layout.fillWidth: true
            visible: !!panel.social && panel.social.ready
            text: "Friend cards contain your public identity and current linked account proofs. Compare the full fingerprint with your friend before adding them."
            color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.Wrap
        }
        ColumnLayout {
            visible: !!panel.social && panel.social.ready
            Layout.fillWidth: true
            spacing: 10
            Text { text: "Linked Minecraft accounts"; color: Colors.bone; font.pixelSize: 16 }
            Repeater {
                model: panel.links
                delegate: ColumnLayout {
                    id: linked
                    required property var modelData
                    Layout.fillWidth: true
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: linked.modelData.name; textFormat: Text.PlainText; color: Colors.text; elide: Text.ElideRight }
                        TextLink { text: "Unlink"; enabled: !!panel.social && !panel.social.busy; onClicked: { unlink.uuid = linked.modelData.uuid; unlink.open(); } }
                    }
                    Text { Layout.fillWidth: true; text: linked.modelData.uuid; font.family: "monospace"; font.pixelSize: 11; color: Colors.subtext; wrapMode: Text.WrapAnywhere }
                    Text { Layout.fillWidth: true; text: linked.modelData.current ? "Account proof valid until " + linked.modelData.expires : "Account proof expired — refresh the link below"; font.pixelSize: 12; color: linked.modelData.current ? Colors.accent : Colors.warning; wrapMode: Text.Wrap }
                }
            }
            Text { visible: !panel.links.length; text: "No accounts linked yet."; color: Colors.subtext; font.pixelSize: 13 }
            RowLayout {
                Layout.fillWidth: true
                SelectBox { id: accountChoice; Layout.fillWidth: true; model: panel.profiles; textRole: "name"; displayText: panel.profiles.length ? currentText : "No Microsoft accounts in Prism"; Accessible.name: "Minecraft account to link" }
                ActionButton {
                    text: panel.social && panel.social.busy ? "Working…" : "Link / refresh"
                    implicitWidth: contentItem.implicitWidth + 32
                    enabled: !!panel.social && !panel.social.busy && accountChoice.currentIndex >= 0
                    onClicked: panel.social.linkAccount(panel.profiles[accountChoice.currentIndex].id)
                }
            }
            Text {
                Layout.fillWidth: true
                text: "Linking contacts Minecraft using the sign-in already saved by Prism. Each proof verifies an account UUID; display names are labels. Expired proofs need refreshing before sharing."
                color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.Wrap
            }
            TextLink { text: "Manage Minecraft sign-ins →"; onClicked: panel.controller.navigate("accounts") }
        }
    }
    FileDialog { id: saveCard; title: "Export friend card"; fileMode: FileDialog.SaveFile; defaultSuffix: "prismarine-friend"; nameFilters: ["Prismarine friend card (*.prismarine-friend)"]; onAccepted: panel.social.exportCard(selectedFile) }
    ConfirmDialog {
        id: unlink
        property string uuid: ""
        anchors.centerIn: Overlay.overlay
        title: "Unlink Minecraft account?"
        message: "This removes the link from new friend cards. Proofs you already shared remain valid until they expire. Your Minecraft sign-in stays available in Prism."
        confirmText: "Unlink"
        onConfirmed: panel.social.unlinkAccount(uuid)
    }
}
