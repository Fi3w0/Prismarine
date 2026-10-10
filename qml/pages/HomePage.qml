import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: home
    required property var controller
    readonly property var library: controller.instances.allInstances
    readonly property var latest: library.length ? library[0] : ({})
    contentWidth: availableWidth
    clip: true
    ColumnLayout {
        width: home.availableWidth
        spacing: 22
        HomeHero {
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
                Layout.fillWidth: true
                spacing: 16
                Text {
                    text: "Recently played"
                    color: Colors.bone
                    font.family: Colors.displayFont
                    font.pixelSize: 22
                    font.letterSpacing: 2
                }
                TextLink {
                    text: "View library →"
                    Layout.alignment: Qt.AlignBaseline
                    onClicked: controller.navigate("library")
                }
                Item {
                    Layout.fillWidth: true
                }
            }
            RecentInstances {
                controller: home.controller
            }
            HomeServers {
                Layout.topMargin: 6
                controller: home.controller
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 10
                columns: home.width < 850 ? 2 : 3
                columnSpacing: 18
                rowSpacing: 18
                HomeWorlds {
                    controller: home.controller
                }
                HomeStats {
                    controller: home.controller
                }
                HomeNews {
                    controller: home.controller
                }
            }
            HomePlaytime {
                Layout.topMargin: 2
                controller: home.controller
            }
        }
        Item {
            Layout.preferredHeight: 28
        }
    }
}
