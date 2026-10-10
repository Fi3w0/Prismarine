import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: panel
    required property var controller
    readonly property var social: controller.social
    readonly property var contacts: social ? social.friends : []
    implicitHeight: body.implicitHeight + 40
    radius: 14; color: Colors.surface; border.color: Colors.border
    ColumnLayout {
        id: body
        anchors { top: parent.top; left: parent.left; right: parent.right; margins: 20 }
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            Text { Layout.fillWidth: true; text: "Your friends"; font.family: Colors.displayFont; font.pixelSize: 22; color: Colors.bone }
            ActionButton { text: "Add friend"; implicitWidth: contentItem.implicitWidth + 32; enabled: !!panel.social && panel.social.ready && !panel.social.busy; onClicked: openCard.open() }
        }
        Text {
            Layout.fillWidth: true
            visible: !panel.contacts.length
            text: "Start with a friend card. No directory, follower counts, or account on someone else’s server."
            color: Colors.subtext; font.pixelSize: 14; wrapMode: Text.Wrap
        }
        Repeater {
            model: panel.contacts
            delegate: Rectangle {
                id: friend
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: friendBody.implicitHeight + 24
                radius: 10; color: Colors.inset
                ColumnLayout {
                    id: friendBody
                    anchors { top: parent.top; left: parent.left; right: parent.right; margins: 12 }
                    spacing: 6
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: friend.modelData.name; textFormat: Text.PlainText; font.pixelSize: 16; font.weight: Font.DemiBold; color: Colors.text; elide: Text.ElideRight }
                        Text { text: friend.modelData.nearby ? "Nearby" : "Saved friend"; font.pixelSize: 12; color: friend.modelData.nearby ? Colors.accent : Colors.subtext }
                        TextLink { text: "Remove"; enabled: !!panel.social && panel.social.ready && !panel.social.busy; onClicked: { remove.key = friend.modelData.key; remove.open(); } }
                    }
                    Text { Layout.fillWidth: true; text: friend.modelData.fingerprint; font.family: "monospace"; font.pixelSize: 11; color: Colors.subtext; wrapMode: Text.WrapAnywhere }
                    Repeater {
                        model: friend.modelData.accounts
                        delegate: Text {
                            required property var modelData
                            Layout.fillWidth: true
                            text: modelData.name + " · " + modelData.uuid + (modelData.current ? " · current proof" : " · expired proof")
                            textFormat: Text.PlainText; color: modelData.current ? Colors.accent : Colors.warning; font.pixelSize: 11; wrapMode: Text.WrapAnywhere
                        }
                    }
                    Text { visible: !friend.modelData.accounts.length; text: "No Minecraft account proof shared"; color: Colors.subtext; font.pixelSize: 12 }
                }
            }
        }
        Rectangle { Layout.fillWidth: true; height: 1; color: Colors.border; Layout.topMargin: 6 }
        ToggleSwitch {
            objectName: "lanDiscoverySwitch"
            text: "Find saved friends on this network"
            enabled: !!panel.social && panel.social.ready && !panel.social.busy
            checked: !!panel.social && panel.social.discovering
            onToggled: panel.social.setDiscovering(checked)
        }
        Text {
            Layout.fillWidth: true
            text: "Off by default. When enabled, your public identity is visible on this LAN. Only saved friends appear here. Locking or closing Prismarine turns discovery off."
            color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.Wrap
        }
    }
    FileDialog {
        id: openCard
        title: "Review a friend card"
        nameFilters: ["Prismarine friend card (*.prismarine-friend)", "JSON (*.json)"]
        onAccepted: if (panel.social.reviewFriend(selectedFile)) { compare.checked = false; review.open(); }
    }
    MotionDialog {
        id: review
        objectName: "friendReviewDialog"
        anchors.centerIn: Overlay.overlay
        modal: true; width: Math.min(560, panel.controller.width - 80); padding: 24
        title: "Review friend card"
        standardButtons: Dialog.Cancel
        onRejected: panel.social.clearReview()
        background: Rectangle { radius: 14; color: Colors.surface; border.color: Colors.border }
        contentItem: ScrollView {
            id: reviewScroll
            implicitHeight: Math.min(reviewBody.implicitHeight, panel.controller.height - 220)
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
            id: reviewBody
            width: reviewScroll.availableWidth
            spacing: 14
            Text { Layout.fillWidth: true; text: panel.social ? panel.social.pendingFriend.name || "" : ""; textFormat: Text.PlainText; font.pixelSize: 22; color: Colors.bone; wrapMode: Text.Wrap }
            Text { Layout.fillWidth: true; text: panel.social ? panel.social.pendingFriend.fingerprint || "" : ""; font.family: "monospace"; color: Colors.accent; wrapMode: Text.WrapAnywhere }
            Text { Layout.fillWidth: true; text: "A valid signature proves control of this key. Confirm this fingerprint with your friend through a channel you trust. Names alone do not identify someone."; color: Colors.subtext; wrapMode: Text.Wrap }
            Text { Layout.fillWidth: true; text: panel.social && panel.social.pendingFriend.accounts ? panel.social.pendingFriend.accounts.length + " current Minecraft account proof(s)" : ""; color: Colors.text }
            Repeater {
                model: panel.social ? panel.social.pendingFriend.accounts || [] : []
                delegate: Text {
                    required property var modelData
                    Layout.fillWidth: true
                    text: modelData.name + " · " + modelData.uuid
                    textFormat: Text.PlainText; color: Colors.subtext; wrapMode: Text.WrapAnywhere; font.pixelSize: 12
                }
            }
            CheckBox { id: compare; objectName: "confirmFriendFingerprint"; text: "I checked this is my friend’s fingerprint" }
            ActionButton {
                objectName: "saveFriendButton"
                text: "Save friend"; primary: true; implicitWidth: contentItem.implicitWidth + 32; enabled: compare.checked
                onClicked: if (panel.social.acceptFriend()) review.accept()
            }
            }
        }
    }
    ConfirmDialog {
        id: remove
        property string key: ""
        anchors.centerIn: Overlay.overlay
        title: "Remove friend?"; message: "Their invites will no longer be trusted and they will disappear from LAN discovery."; confirmText: "Remove"; danger: true
        onConfirmed: panel.social.removeFriend(key)
    }
}
