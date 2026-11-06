import QtQuick

// The page the window shows, changed with the shared page motion.
MotionLoader {
    id: pages
    required property var controller
    readonly property string page: controller.page
    sourceComponent: page === "home" ? homePage : page === "instance" ? instancePage : page === "settings" ? settingsPage
        : page === "accounts" ? accountsPage : page === "friends" ? friendsPage : page === "browse" ? browsePage
        : page === "session" && controller.session ? sessionPage : libraryPage
    opacity: 1

    Component {
        id: libraryPage
        LibraryPage {
            controller: pages.controller
        }
    }
    Component {
        id: homePage
        HomePage {
            controller: pages.controller
        }
    }
    Component {
        id: instancePage
        InstancePage {
            controller: pages.controller
        }
    }
    Component {
        id: settingsPage
        SettingsPage {
            controller: pages.controller
        }
    }
    Component {
        id: friendsPage
        FriendsPage { controller: pages.controller }
    }
    Component {
        id: accountsPage
        AccountsPage {
            controller: pages.controller
        }
    }
    Component {
        id: sessionPage
        SessionPage {
            controller: pages.controller
            tab: pages.controller.sessionTab
        }
    }
    Component {
        id: browsePage
        BrowsePage {
            controller: pages.controller
        }
    }
}
