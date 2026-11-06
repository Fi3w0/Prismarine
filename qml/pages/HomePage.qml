import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: home
    required property var controller
    function showSection(key) { return controller.preferences.homeSections.indexOf(key) >= 0; }
    readonly property var library: controller.instances.allInstances.slice().sort((a, b) => (b.lastLaunchMs || 0) - (a.lastLaunchMs || 0))
    readonly property var latest: library.length ? library[0] : ({})
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: home.availableWidth
        spacing: 22
        HomeHero {
            objectName: "home_hero"
            Layout.leftMargin: 28
            Layout.rightMargin: 28
            Layout.topMargin: 24
            controller: home.controller
            latest: home.latest
            hasInstances: home.library.length > 0
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.leftMargin: 36
            Layout.rightMargin: 36
            spacing: 18
            RowLayout {
                visible: home.showSection("recent")
                Layout.fillWidth: true
                spacing: 16
                Text {
                    text: "Jump back in"
                    color: Colors.bone
                    font.family: Colors.displayFont
                    font.pixelSize: Typography.panelTitle
                    font.letterSpacing: 2
                }
                Item {
                    Layout.fillWidth: true
                }
                TextLink {
                    text: "View library →"
                    Layout.alignment: Qt.AlignBaseline
                    onClicked: controller.navigate("library")
                }
            }
            RecentInstances {
                objectName: "home_recent"
                visible: home.showSection("recent")
                controller: home.controller
                library: home.library
            }
            GridLayout {
                Layout.fillWidth: true
                columns: width >= 900 && home.showSection("servers") && home.showSection("news") ? 2 : 1
                columnSpacing: 20
                rowSpacing: 20
                HomeServers {
                    objectName: "home_servers"
                    visible: home.showSection("servers")
                    Layout.preferredWidth: 1
                    Layout.alignment: Qt.AlignTop
                    controller: home.controller
                }
                HomeNews {
                    objectName: "home_news"
                    visible: home.showSection("news")
                    Layout.preferredWidth: 1
                    controller: home.controller
                }
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                visible: home.showSection("worlds") || home.showSection("stats")
                columns: Math.max(1, Math.min(home.width < 850 ? 2 : 3, ["worlds", "stats"].filter(key => home.showSection(key)).length))
                columnSpacing: 18
                rowSpacing: 18
                HomeWorlds {
                    objectName: "home_worlds"
                    visible: home.showSection("worlds")
                    controller: home.controller
                }
                HomeStats {
                    objectName: "home_stats"
                    visible: home.showSection("stats")
                    controller: home.controller
                }

            }
            HomePlaytime {
                objectName: "home_playtime"
                visible: home.showSection("playtime")
                Layout.topMargin: 2
                controller: home.controller
            }
        }
        Item {
            Layout.preferredHeight: 28
        }
    }
}
