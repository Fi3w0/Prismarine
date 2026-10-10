import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

NavButton {
    id: switcher
    required property var controller
    readonly property var profiles: controller.instances.accounts
    readonly property var activeProfile: profiles.find(it => it.active) || ({})
    objectName: "accountSwitcher"
    hint: (activeProfile.name || "Accounts") + " · right-click to switch"
    checked: controller.page === "accounts"
    onClicked: controller.navigate("accounts")
    contentItem: SkinAvatar { skin: switcher.activeProfile.skin || ""; size: 34 }
    TapHandler { acceptedButtons: Qt.RightButton; onTapped: accountMenu.popup() }
    Menu {
        id: accountMenu
        objectName: "accountSwitchMenu"
        x: switcher.width + 8
        y: Math.min(0, switcher.height - implicitHeight)
        width: 240
        padding: 6
        background: Rectangle { radius: 12; color: Colors.surface; border.color: Colors.border }
        Repeater {
            model: switcher.profiles
            delegate: MenuItem {
                id: entry
                required property var modelData
                objectName: "accountChoice_" + modelData.id
                text: modelData.name
                implicitHeight: 52
                onTriggered: {
                    // setDefault rebuilds this Repeater, destroying the delegate's context.
                    const controller = switcher.controller;
                    const name = modelData.name;
                    if (controller.accountManager.setDefault(modelData.id))
                        controller.notify("Playing as " + name);
                }
                background: Rectangle { radius: 8; color: entry.highlighted ? Colors.surfaceHi : "transparent" }
                contentItem: RowLayout {
                    SkinAvatar { skin: entry.modelData.skin || ""; size: 32 }
                    Text { Layout.fillWidth: true; text: entry.modelData.name; color: Colors.text; font.pixelSize: 14 }
                    Text { text: entry.modelData.active ? "✓" : ""; color: Colors.accent }
                }
            }
        }
        MenuSeparator {}
        MenuItem { text: "Manage accounts"; onTriggered: switcher.controller.navigate("accounts") }
        enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Colors.animations ? 200 : 0 } }
        exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Colors.animations ? 140 : 0 } }
    }
}
