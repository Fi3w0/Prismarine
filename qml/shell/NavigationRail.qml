import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    required property var controller
    signal newInstanceRequested
    signal revealCrownRequested

    Layout.preferredWidth: 72
    Layout.fillHeight: true
    color: Colors.mantle
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Colors.border
    }
    ColumnLayout {
        anchors {
            fill: parent
            margins: 14
            topMargin: 16
            bottomMargin: 20
        }
        spacing: 10
        Button {
            objectName: "brandMark"
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
            checked: controller.page === "home"
            onClicked: controller.navigate("home")
        }
        NavButton {
            iconName: "library"
            hint: "Library"
            checked: controller.page === "library" || controller.page === "instance"
            onClicked: controller.navigate("library")
        }
        NavButton {
            iconName: "browse"
            hint: "Browse content"
            checked: controller.page === "browse"
            onClicked: controller.navigate("browse")
        }
        NavButton {
            objectName: "friendsNavButton"
            visible: !!controller.social
            iconName: "accounts"
            hint: "Friends · Beta"
            checked: controller.page === "friends"
            onClicked: controller.navigate("friends")
        }
        NavButton {
            iconName: "plus"
            hint: "New instance or import"
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
            hint: liveGames > 1 ? "Now playing · " + liveGames + " games" : live ? "Now playing"
                : controller.session && controller.session.active ? "Last session" : "Now playing · nothing running"
            checked: controller.page === "session"
            onClicked: controller.navigate("session")
            Rectangle {
                visible: parent.live
                anchors {
                    top: parent.top
                    right: parent.right
                    margins: 7
                }
                width: 8
                height: 8
                radius: 4
                color: Colors.accent
                SequentialAnimation on opacity {
                    running: Colors.animations && parent.visible
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
            objectName: "searchNavButton"
            iconName: "search"
            hint: "Search everything · Ctrl+K"
            onClicked: controller.openPalette()
        }
        NavButton {
            iconName: "refresh"
            hint: "Refresh · Ctrl+R"
            onClicked: controller.reloadLibrary()
        }
        NavButton {
            iconName: "settings"
            hint: "Settings"
            checked: controller.page === "settings"
            onClicked: controller.navigate("settings")
        }
        AccountSwitcher { controller: parent.parent.controller }
    }
}
