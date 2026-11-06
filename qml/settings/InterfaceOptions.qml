import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: options
    required property var controller
    readonly property var preferences: controller.preferences
    Layout.fillWidth: true
    spacing: 20
    AppearancePreview { controller: options.controller; section: "Interface" }
    PaletteCustomization { preferences: options.preferences }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: themeRow.implicitHeight + 40
        radius: 18; color: Colors.surface; border.color: Colors.border
        SettingsChoiceRow {
            id: themeRow
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            objectName: "theme"
            title: qsTr("Theme")
            detail: qsTr("Deep sea is the default. System follows your desktop.")
            choices: [{label: qsTr("Deep sea"), value: "deep"}, {label: qsTr("Light"), value: "light"}, {label: qsTr("System"), value: "system"}]
            value: options.preferences.theme
            onChosen: value => options.preferences.theme = value
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: layoutOptions.implicitHeight + 40
        radius: 18; color: Colors.surface; border.color: Colors.border
        ColumnLayout {
            id: layoutOptions
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 20
            SettingsChoiceRow {
                objectName: "interfaceSize"
                title: qsTr("Interface size")
                detail: options.preferences.interfaceSize !== (options.controller.appInfo.interfaceSize || 100) ? qsTr("Reopen Prismarine after applying to use this size.") : qsTr("Scales text and controls together. Applies on next launch.")
                choices: [{label: qsTr("Compact"), value: 90}, {label: qsTr("Default"), value: 100}, {label: qsTr("Large"), value: 115}]
                value: options.preferences.interfaceSize
                onChosen: value => options.preferences.interfaceSize = value
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
            SettingsChoiceRow {
                objectName: "whilePlaying"
                title: qsTr("While a game is running")
                detail: qsTr("What Prismarine's window does once the game window opens.")
                choices: [{label: qsTr("Keep open"), value: "keep"}, {label: qsTr("Minimise"), value: "minimize"}, {label: qsTr("Hide"), value: "hide"}]
                value: options.preferences.whilePlaying
                onChosen: value => options.preferences.whilePlaying = value
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: toggles.implicitHeight + 40
        radius: 18; color: Colors.surface; border.color: Colors.border
        ColumnLayout {
            id: toggles
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 20
            SettingsToggleRow {
                objectName: "animations"
                title: qsTr("Animations")
                detail: qsTr("Hover lifts and smooth transitions. Turn off for reduced motion.")
                value: options.preferences.animations
                onToggled: value => options.preferences.animations = value
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
            SettingsToggleRow {
                objectName: "prismConsole"
                title: qsTr("Let Prism open its console window")
                detail: qsTr("Off: Prism keeps its console closed. Now playing still has the live log and crash help.")
                value: options.preferences.prismConsole
                onToggled: value => options.preferences.prismConsole = value
            }
        }
    }
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: extraOptions.implicitHeight + 40
        radius: 18; color: Colors.surface; border.color: Colors.border
        ColumnLayout {
            id: extraOptions
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
            spacing: 20
            Text { text: qsTr("Make it yours"); color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: Typography.sectionTitle }
            SettingsChoiceRow {
                objectName: "startPage"
                title: qsTr("Start page")
                detail: qsTr("What opens when you launch Prismarine.")
                choices: [{label: qsTr("Home"), value: "home"}, {label: qsTr("Library"), value: "library"}]
                value: options.preferences.startPage
                onChosen: value => options.preferences.startPage = value
            }
            SettingsChoiceRow {
                objectName: "scrollSpeed"
                title: qsTr("Scroll speed")
                detail: qsTr("How far each mouse wheel step moves, based on your system setting.")
                choices: [{label: qsTr("Standard"), value: 1}, {label: qsTr("Fast"), value: 2}, {label: qsTr("Faster"), value: 3}]
                value: options.preferences.scrollSpeed
                onChosen: value => options.preferences.scrollSpeed = value
            }
            SettingsToggleRow {
                objectName: "controllerEnabledRow"
                visible: !!options.controller.gamepad && options.controller.gamepad.available
                title: qsTr("Controller")
                detail: !!options.controller.gamepad && options.controller.gamepad.connected
                    ? qsTr("Connected: %1. Bottom button selects, right button goes back, top button opens details, left button opens menus, Start or Options plays, shoulder buttons switch pages, right stick scrolls. It only works while Prismarine is in front, so games keep it to themselves.").arg(options.controller.gamepad.deviceName)
                    : qsTr("Move around with a controller. None is connected right now.")
                value: options.preferences.controllerEnabled
                onToggled: value => options.preferences.controllerEnabled = value
            }
            SettingsToggleRow {
                objectName: "friendsEnabledRow"
                title: qsTr("Friends")
                detail: qsTr("Show the Friends tab and its icon. Hiding it also stops finding friends on your network; your friends and identity are kept.")
                value: options.preferences.friendsEnabled
                onToggled: value => options.preferences.friendsEnabled = value
            }
            HomePreferences { controller: options.controller }
        }
    }
}
