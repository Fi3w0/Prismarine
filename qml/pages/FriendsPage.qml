import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: page
    objectName: "friendsPage"
    required property var controller
    readonly property var social: controller.social
    clip: true
    contentWidth: availableWidth
    ColumnLayout {
        width: page.availableWidth
        spacing: 22
        ColumnLayout {
            Layout.fillWidth: true
            Layout.margins: 28
            spacing: 8
            RowLayout {
                spacing: 12
                Text { text: "Friends, on your terms"; color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: 30 }
                Rectangle {
                    implicitWidth: betaLabel.implicitWidth + 18
                    implicitHeight: 26
                    radius: 6
                    color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12)
                    border.color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.4)
                    Text {
                        id: betaLabel
                        anchors.centerIn: parent
                        text: "BETA"
                        color: Colors.accent
                        font.pixelSize: 11
                        font.weight: Font.DemiBold
                        font.letterSpacing: 1
                    }
                }
            }
            Text {
                Layout.fillWidth: true
                text: "One optional Prismarine identity for your Minecraft accounts. Exchange friend cards and invites through any chat you already use."
                color: Colors.subtext; font.pixelSize: 14; wrapMode: Text.Wrap
            }
            Text {
                visible: !page.social
                text: "Social features are unavailable in this session."; color: Colors.subtext
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 16
                columns: page.availableWidth > 1100 ? 2 : 1
                columnSpacing: 22; rowSpacing: 22
                visible: !!page.social
                SocialIdentityCard { Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; controller: page.controller }
                SocialFriendsCard { Layout.fillWidth: true; Layout.alignment: Qt.AlignTop; controller: page.controller }
            }
            SocialInvitesCard {
                Layout.fillWidth: true
                Layout.topMargin: 14
                visible: !!page.social && page.social.ready
                controller: page.controller
            }
        }
    }
}
