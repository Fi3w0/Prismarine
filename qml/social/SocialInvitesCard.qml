import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: panel
    required property var controller
    readonly property var social: controller.social
    readonly property var contacts: social ? social.friends : []
    readonly property var invite: social ? social.pendingInvite : ({})
    readonly property var instances: controller.instances.allInstances
    property url packFile: ""
    property bool composing: false
    implicitHeight: body.implicitHeight + 40
    color: Colors.surface; radius: 14; border.color: Colors.border
    ColumnLayout {
        id: body
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 20 }
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Play together"; font.family: Colors.displayFont; font.pixelSize: 22; color: Colors.bone }
            ActionButton { text: "Open invite"; implicitWidth: contentItem.implicitWidth + 32; enabled: !!panel.social && !panel.social.busy; onClicked: openInvite.open() }
            ActionButton { text: panel.composing ? "Close editor" : "Create invite"; implicitWidth: contentItem.implicitWidth + 32; enabled: panel.contacts.length > 0 && !!panel.social && !panel.social.busy; onClicked: panel.composing = !panel.composing }
        }
        Text {
            Layout.fillWidth: true
            text: "Send a server address, an exported modpack, or both. Invites last seven days and only work for the friend you choose. Share the invite file and pack through your usual chat or file sharing app."
            color: Colors.subtext; font.pixelSize: 13; wrapMode: Text.Wrap
        }
        ColumnLayout {
            visible: panel.composing
            Layout.fillWidth: true
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text { text: "To"; color: Colors.subtext }
                SelectBox { id: recipient; Layout.preferredWidth: 240; model: panel.contacts; textRole: "name"; Accessible.name: "Invite recipient" }
                InputField { id: inviteTitle; Layout.fillWidth: true; placeholderText: "Invite title"; maximumLength: 64; Accessible.name: "Invite title" }
            }
            InputField { id: server; Layout.fillWidth: true; placeholderText: "Server address (optional), e.g. play.example.com:25565"; maximumLength: 260; Accessible.name: "Server address" }
            RowLayout {
                Layout.fillWidth: true
                ActionButton { text: "Choose exported pack"; implicitWidth: contentItem.implicitWidth + 32; onClicked: choosePack.open() }
                Text { Layout.fillWidth: true; text: panel.packFile.toString() ? decodeURIComponent(panel.packFile.toString().split('/').pop()) : "No pack selected"; textFormat: Text.PlainText; color: Colors.subtext; elide: Text.ElideMiddle }
                TextLink { visible: panel.packFile.toString() !== ""; text: "Clear"; onClicked: panel.packFile = "" }
            }
            Text { Layout.fillWidth: true; text: "Use Export or share on an instance to create a pack first. Invites are signed, readable files; anyone with the file can read its address and title."; font.pixelSize: 12; color: Colors.subtext; wrapMode: Text.Wrap }
            ActionButton {
                text: panel.social && panel.social.busy ? "Preparing…" : "Save signed invite"
                primary: true; implicitWidth: contentItem.implicitWidth + 32
                enabled: !!panel.social && !panel.social.busy && recipient.currentIndex >= 0 && inviteTitle.text.trim().length > 0 && (server.text.trim().length > 0 || panel.packFile.toString() !== "")
                onClicked: saveInvite.open()
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: !!panel.invite.id
            spacing: 10
            Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border }
            Text { Layout.fillWidth: true; text: (panel.invite.title || "") + " · from " + (panel.invite.from || ""); textFormat: Text.PlainText; color: Colors.bone; font.pixelSize: 18; wrapMode: Text.Wrap }
            Text { Layout.fillWidth: true; text: panel.invite.fingerprint || ""; font.family: "monospace"; color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.WrapAnywhere }
            Text { Layout.fillWidth: true; text: "Expires " + new Date(panel.invite.expires || 0).toLocaleString(); color: Colors.subtext; font.pixelSize: 12 }
            Text { Layout.fillWidth: true; visible: !!panel.invite.server; text: "Server: " + (panel.invite.server || ""); textFormat: Text.PlainText; color: Colors.text; wrapMode: Text.Wrap }
            RowLayout {
                Layout.fillWidth: true
                visible: !!panel.invite.server
                SelectBox { id: instance; Layout.fillWidth: true; model: panel.instances; textRole: "name"; Accessible.name: "Instance for server invite" }
                ActionButton {
                    text: "Join with this instance"; implicitWidth: contentItem.implicitWidth + 32
                    enabled: instance.currentIndex >= 0 && !!panel.social && !panel.social.busy
                    onClicked: panel.social.joinInvite(panel.instances[instance.currentIndex].instanceId)
                }
            }
            Text { Layout.fillWidth: true; visible: !!panel.invite.pack; text: "Pack: " + (panel.invite.pack ? panel.invite.pack.name : ""); textFormat: Text.PlainText; color: Colors.text; wrapMode: Text.Wrap }
            ActionButton {
                visible: !!panel.invite.pack
                text: panel.social && panel.social.busy ? "Verifying pack…" : "Choose pack, verify & import"
                implicitWidth: contentItem.implicitWidth + 32
                enabled: !!panel.social && !panel.social.busy && panel.controller.packImporter.state !== "extracting" && panel.controller.packImporter.state !== "downloading"
                onClicked: openPack.open()
            }
            TextLink { text: "Dismiss invite"; enabled: !!panel.social && !panel.social.busy; onClicked: panel.social.clearReview() }
        }
    }
    FileDialog { id: choosePack; title: "Choose an exported pack to share"; nameFilters: ["Modpacks (*.mrpack *.zip)"]; onAccepted: panel.packFile = selectedFile }
    FileDialog {
        id: saveInvite; title: "Save signed invite"; fileMode: FileDialog.SaveFile; defaultSuffix: "prismarine-invite"; nameFilters: ["Prismarine invite (*.prismarine-invite)"]
        onAccepted: panel.social.exportInvite(panel.contacts[recipient.currentIndex].key, inviteTitle.text.trim(), server.text.trim(), panel.packFile, selectedFile)
    }
    FileDialog { id: openInvite; title: "Review an invite"; nameFilters: ["Prismarine invite (*.prismarine-invite)", "JSON (*.json)"]; onAccepted: panel.social.reviewInvite(selectedFile) }
    FileDialog { id: openPack; title: "Choose the pack received from your friend"; nameFilters: ["Modpacks (*.mrpack *.zip)"]; onAccepted: panel.social.importInvitedPack(selectedFile) }
}
