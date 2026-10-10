import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: accounts
    required property var controller
    property int selected: Math.max(0, profiles.findIndex(it => it.active))
    readonly property var profiles: controller.instances.accounts
    readonly property var profile: profiles[Math.min(selected, profiles.length - 1)] || ({})
    // A skin, arm model and cape picked here are previewed until Apply sends them.
    property string chosenSkin: ""
    property string chosenVariant: (profile.skinVariant || "CLASSIC").toUpperCase()
    property string chosenCape: profile.cape || ""
    readonly property var chosenEntry: controller.accountManager.savedSkins.find(it => it.file === chosenSkin) || null
    readonly property var chosenCapeEntry: (profile.capes || []).find(it => it.id === chosenCape) || null
    readonly property bool skinPending: chosenSkin !== "" || chosenVariant !== (profile.skinVariant || "CLASSIC").toUpperCase()
    readonly property bool capePending: chosenCape !== (profile.cape || "")
    readonly property bool pendingChange: skinPending || capePending
    // Saving reloads the account list; only switching accounts discards the choices.
    readonly property string profileId: profile.id || ""
    onProfileIdChanged: resetChoices()
    function resetChoices() {
        chosenSkin = "";
        chosenVariant = (profile.skinVariant || "CLASSIC").toUpperCase();
        chosenCape = profile.cape || "";
    }
    function applyChoices() {
        if (skinPending)
            controller.accountManager.applySkin(profile.id, chosenSkin, chosenVariant);
        else if (capePending)
            controller.accountManager.setCape(profile.id, chosenCape);
    }
    Connections {
        target: accounts.controller.accountManager
        function onProfileUpdated(message) {
            accounts.chosenSkin = "";
            // A skin and a cape chosen together are sent one after the other.
            if (accounts.capePending)
                accounts.controller.accountManager.setCape(accounts.profile.id, accounts.chosenCape);
            else
                accounts.controller.notify(message);
        }
    }
    ConfirmDialog {
        id: removeAccount
        objectName: "removeAccountDialog"
        anchors.centerIn: parent
        title: "Remove " + (accounts.profile.name || "account") + "?"
        message: "This removes the saved sign-in from Prism and Prismarine. The Minecraft account itself is not affected."
        confirmText: "Remove"
        danger: true
        onConfirmed: if (controller.accountManager.remove(accounts.profile.id)) controller.notify("Account removed")
    }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        Rectangle {
            Layout.preferredWidth: accounts.width < 1100 ? 220 : 260
            Layout.fillHeight: true
            color: Colors.surface
            ColumnLayout {
                anchors.fill: parent
                anchors.margins: 20
                spacing: 12
                Text { text: "Accounts"; color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: 28; Layout.bottomMargin: 16 }
                Repeater {
                    model: accounts.profiles
                    delegate: ItemDelegate {
                        id: row
                        required property var modelData
                        required property int index
                        Layout.fillWidth: true
                        implicitHeight: 74
                        padding: 12
                        onClicked: accounts.selected = index
                        background: Rectangle { radius: 10; color: row.hovered || accounts.selected === row.index ? Colors.surfaceHi : Colors.mantle; border.color: accounts.selected === row.index ? Qt.darker(Colors.accent, 1.5) : Colors.border; Behavior on color { ColorAnimation { duration: Colors.animations ? 200 : 0 } } }
                        contentItem: RowLayout {
                            spacing: 12
                            SkinAvatar { skin: row.modelData.skin || ""; size: 38 }
                            ColumnLayout {
                                Layout.fillWidth: true
                                spacing: 5
                                Text { Layout.fillWidth: true; text: row.modelData.name; color: Colors.text; font.pixelSize: 15; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { text: row.modelData.active ? "Default account" : "Minecraft profile"; color: row.modelData.active ? Colors.accent : Colors.subtext; font.pixelSize: 11 }
                            }
                        }
                    }
                }
                ActionButton { Layout.fillWidth: true; text: "+  Add Microsoft account"; implicitWidth: 0; font.pixelSize: 12; onClicked: controller.instances.openPrism() }
                ActionButton {
                    visible: !!controller.social
                    Layout.fillWidth: true; implicitWidth: 0; font.pixelSize: 12
                    text: "Identity & friends · Beta"
                    onClicked: controller.navigate("friends")
                }
                Item { Layout.fillHeight: true }
                Text { Layout.fillWidth: true; text: "Right-click your avatar in the rail to switch accounts."; color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.Wrap; lineHeight: 1.35 }
                Text { Layout.fillWidth: true; text: "Microsoft sign-in opens Prism Launcher."; color: Colors.subtext; font.pixelSize: 11; wrapMode: Text.Wrap }
            }
        }
        ScrollView {
            id: accountScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 24
            clip: true
            contentWidth: availableWidth
            GridLayout {
                width: accountScroll.availableWidth
                columns: accountScroll.availableWidth > 700 ? 2 : 1
                columnSpacing: 20
                rowSpacing: 20
                Rectangle {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 260
                    Layout.preferredWidth: accountScroll.availableWidth * 0.46
                    Layout.preferredHeight: 560
                    Layout.alignment: Qt.AlignTop
                    color: Colors.surface
                    radius: 14
                    border.color: Colors.border
                    ColumnLayout {
                        anchors.fill: parent
                        anchors.margins: 16
                        spacing: 12
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 10
                            Text {
                                text: accounts.profile.name || "No account"
                                color: Colors.bone
                                font.family: Colors.displayFont
                                font.pixelSize: 26
                                font.letterSpacing: 1
                            }
                            Text {
                                Layout.fillWidth: true
                                text: "Java Edition"
                                color: Colors.subtext
                                font.pixelSize: 12
                            }
                        }
                        SkinPreview {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            skin: accounts.chosenEntry ? accounts.chosenEntry.url : accounts.profile.skin || ""
                            variant: accounts.chosenVariant
                            cape: accounts.chosenCapeEntry ? accounts.chosenCapeEntry.url : ""
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            spacing: 8
                            Repeater {
                                model: [{ label: "Classic arms", key: "CLASSIC" }, { label: "Slim arms", key: "SLIM" }]
                                delegate: ActionButton {
                                    required property var modelData
                                    Layout.fillWidth: true
                                    implicitWidth: 0
                                    implicitHeight: 36
                                    font.pixelSize: 12
                                    text: modelData.label
                                    checked: accounts.chosenVariant === modelData.key
                                    onClicked: accounts.chosenVariant = modelData.key
                                }
                            }
                        }
                        RowLayout {
                            Layout.fillWidth: true
                            visible: accounts.pendingChange
                            spacing: 8
                            Text {
                                Layout.fillWidth: true
                                text: accounts.profile.signedIn ? "Preview only until you apply it." : "Refresh the sign-in in Prism to change skins and capes."
                                color: accounts.profile.signedIn ? Colors.subtext : Colors.warning
                                font.pixelSize: 11
                                wrapMode: Text.Wrap
                            }
                            ActionButton {
                                text: "Reset"
                                implicitWidth: 70
                                implicitHeight: 34
                                font.pixelSize: 12
                                onClicked: accounts.resetChoices()
                            }
                            ActionButton {
                                objectName: "applySkinButton"
                                text: controller.accountManager.busy ? "Applying…" : accounts.skinPending && accounts.capePending ? "Apply both" : accounts.capePending ? "Apply cape" : "Apply skin"
                                primary: true
                                implicitWidth: 110
                                implicitHeight: 34
                                font.pixelSize: 12
                                enabled: !controller.accountManager.busy && !!accounts.profile.signedIn
                                onClicked: accounts.applyChoices()
                            }
                        }
                    }
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    Layout.minimumWidth: 300
                    Layout.preferredWidth: accountScroll.availableWidth * 0.54
                    Layout.alignment: Qt.AlignTop
                    spacing: 20
                    SkinLibrary {
                        Layout.fillWidth: true
                        controller: accounts.controller
                        profile: accounts.profile
                        chosen: accounts.chosenSkin
                        onSkinChosen: file => accounts.chosenSkin = file
                        chosenCape: accounts.chosenCape
                        onCapeChosen: id => accounts.chosenCape = id
                    }
                    ProfileDetails {
                        Layout.fillWidth: true
                        controller: accounts.controller
                        profile: accounts.profile
                        onRemoveRequested: removeAccount.open()
                    }
                }
            }
        }
    }
}
