import QtQuick
import QtQuick.Window
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: rail
    required property var controller
    signal newInstanceRequested
    signal revealCrownRequested

    Layout.preferredWidth: 76
    Layout.fillHeight: true
    color: Colors.rail
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Colors.border
    }
    ColumnLayout {
        anchors {
            fill: parent
            leftMargin: 6
            rightMargin: 6
            topMargin: 10
            bottomMargin: 12
        }
        spacing: 4
        Button {
            objectName: "brandMark"
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 44
            Layout.preferredHeight: 52
            padding: 0
            Accessible.name: "Prismarine"
            onPressAndHold: {
                revealCrownRequested();
            }
            background: Item {}
            contentItem: Image {
                source: "qrc:/assets/logos/" + controller.logoFile
                fillMode: Image.PreserveAspectFit
                sourceSize.width: 100
                sourceSize.height: 100
            }
        }
        NavButton {
            iconName: "home"
            hint: "Home"
            label: "Home"
            checked: controller.page === "home"
            onClicked: controller.navigate("home")
        }
        NavButton {
            iconName: "library"
            hint: "Library"
            label: "Library"
            checked: controller.page === "library" || controller.page === "instance"
            onClicked: controller.navigate("library")
        }
        NavButton {
            iconName: "browse"
            hint: "Browse content"
            label: "Browse"
            checked: controller.page === "browse"
            onClicked: controller.navigate("browse")
        }
        NavButton {
            objectName: "friendsNavButton"
            visible: !!controller.social && controller.friendsEnabled !== false
            iconName: "accounts"
            hint: "Friends · Beta"
            label: "Friends"
            checked: controller.page === "friends"
            onClicked: controller.navigate("friends")
        }
        NavButton {
            iconName: "plus"
            hint: "New instance or import"
            label: "New"
            onClicked: newInstanceRequested()
        }
        NavButton {
            objectName: "sessionNavButton"
            // Always here, so the last session and quick play stay one click away.
            visible: !!controller.session
            // Games running anywhere: the one Prismarine launched, other accounts, Prism itself.
            readonly property int liveGames: controller.games ? controller.games.games.filter(it => it.state !== "exited").length : 0
            readonly property bool live: liveGames > 0 || (!!controller.session && controller.session.active && controller.session.state !== "exited")
            iconName: "play"
            label: "Playing"
            hint: liveGames > 1 ? "Now playing · " + liveGames + " games" : live ? "Now playing"
                : controller.session && controller.session.active ? "Last session" : "Now playing · nothing running"
            checked: controller.page === "session"
            onClicked: controller.navigate("session")
            Rectangle {
                id: liveIndicator
                visible: parent.live
                anchors {
                    top: parent.top
                    left: parent.horizontalCenter
                    topMargin: 7
                    leftMargin: 7
                }
                width: 8
                height: 8
                radius: 4
                color: Colors.accent
                SequentialAnimation on opacity {
                    // Animation's lexical parent is not the indicator; name it explicitly.
                    running: Colors.animations && liveIndicator.visible
                        && !!liveIndicator.Window.window && liveIndicator.Window.window.visible
                        && liveIndicator.Window.window.visibility !== Window.Minimized
                    onRunningChanged: if (!running) liveIndicator.opacity = 1
                    loops: Animation.Infinite
                    NumberAnimation { to: 0.3; duration: 900; easing.type: Easing.InOutSine }
                    NumberAnimation { to: 1; duration: 900; easing.type: Easing.InOutSine }
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
        NavButton {
            iconName: "refresh"
            hint: "Refresh · " + (Qt.platform.os === "osx" ? "⌘R" : "Ctrl+R")
            label: "Refresh"
            onClicked: controller.reloadLibrary()
        }
        NavButton {
            objectName: "settingsNavButton"
            iconName: "settings"
            hint: "Settings"
            label: "Settings"
            checked: controller.page === "settings"
            onClicked: controller.navigate("settings")
        }
    }
}
