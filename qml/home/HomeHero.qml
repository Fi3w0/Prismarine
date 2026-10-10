import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: hero
    required property var controller
    property var latest: ({})
    property bool hasInstances: false

    Layout.fillWidth: true
    Layout.preferredHeight: 250
    HeroBackdrop {
        anchors {
            fill: parent
            margins: 0
        }
        cover: controller.coverFor(hero.latest.instanceId, "hero")
        screenshot: hero.latest.screenshot || ""
        showScreenshot: controller.screenshotFor(hero.latest.instanceId, "hero")
    }
    RowLayout {
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 32
            bottomMargin: 32
        }
        spacing: 26
        InstanceIcon {
            size: 82
            name: hero.latest.name || "P"
            icon: hero.latest.icon || ""
            loader: hero.latest.loader || ""
            visible: hero.hasInstances
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                text: hero.hasInstances ? "Continue playing" : "Welcome to Prismarine"
                font.family: Colors.displayFont
                font.pixelSize: 15
                font.letterSpacing: 3
                color: Colors.brass
            }
            Text {
                Layout.fillWidth: true
                text: hero.latest.name || "Your next adventure"
                font.family: Colors.displayFont
                font.pixelSize: 44
                color: Colors.bone
                elide: Text.ElideRight
            }
            Flow {
                Layout.fillWidth: true
                spacing: 8
                visible: hero.hasInstances
                Chip {
                    text: "Minecraft " + (hero.latest.version || "?")
                    tint: Colors.text
                }
                Chip {
                    text: (hero.latest.loader || "") + " " + (hero.latest.loaderVersion || "")
                    tint: Colors.loaderColor(hero.latest.loader || "")
                }
                Chip {
                    text: (hero.latest.mods || 0) + " mods"
                    tint: Colors.accent
                }
            }
            Text {
                text: hero.hasInstances ? "Played " + hero.latest.played + " · Last played " + hero.latest.lastPlayed : "Create your first instance to begin."
                color: Colors.subtext
                font.pixelSize: 14
            }
        }
        ColumnLayout {
            Layout.preferredWidth: 190
            Layout.maximumWidth: 190
            ActionButton {
                Layout.fillWidth: true
                text: "▶  PLAY"
                primary: true
                enabled: hero.hasInstances
                onClicked: controller.play(hero.latest.instanceId, hero.latest.name)
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                ActionButton {
                    Layout.fillWidth: true
                    implicitWidth: 0
                    implicitHeight: 34
                    font.pixelSize: 12
                    text: "Instance"
                    enabled: hero.hasInstances
                    onClicked: controller.openInstance(hero.latest.instanceId)
                }
                ActionButton {
                    Layout.fillWidth: true
                    implicitWidth: 0
                    implicitHeight: 34
                    font.pixelSize: 12
                    text: "Mods"
                    enabled: hero.hasInstances
                    onClicked: controller.openInstance(hero.latest.instanceId, "mods")
                }
            }
        }
    }
}
