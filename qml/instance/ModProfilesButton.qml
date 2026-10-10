import QtQuick
import QtQuick.Controls

// Saved sets of enabled mods. Applying one only switches mods the profile names.
ActionButton {
    id: button
    required property var controller
    readonly property var contents: controller.details
    readonly property var current: contents.profiles.find(it => it.current)
    objectName: "modProfilesButton"
    text: current ? "Profile: " + current.name + "  ▾" : "Profiles  ▾"
    implicitWidth: Math.min(240, contentItem.implicitWidth + 32)
    enabled: !contents.loading
    onClicked: menu.popup(button, 0, button.height + 4)
    ThemedMenu {
        id: menu
        implicitWidth: 280
        Repeater {
            model: button.contents.profiles
            delegate: ThemedMenuItem {
                required property var modelData
                text: modelData.name
                checkable: false
                checked: modelData.current
                hint: modelData.missing ? modelData.missing + " missing" : modelData.enabledCount + " on"
                onTriggered: {
                    const count = button.contents.applyProfile(modelData.name);
                    if (count >= 0) button.controller.notify(count ? "Applied " + modelData.name + " · " + count + (count === 1 ? " mod switched" : " mods switched") : modelData.name + " is already active");
                }
            }
        }
        MenuSeparator { visible: button.contents.profiles.length > 0; height: visible ? implicitHeight : 0; contentItem: Rectangle { implicitHeight: 1; color: Colors.border } }
        ThemedMenuItem {
            text: "Save current mods as profile…"
            onTriggered: button.controller.saveModProfile()
        }
        ThemedMenu {
            title: "Delete profile"
            enabled: button.contents.profiles.length > 0
            Repeater {
                model: button.contents.profiles
                delegate: ThemedMenuItem {
                    required property var modelData
                    text: modelData.name
                    danger: true
                    onTriggered: if (button.contents.deleteProfile(modelData.name)) button.controller.notify("Profile deleted")
                }
            }
        }
    }
}
