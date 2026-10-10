import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    required property var controller
    required property string section
    signal sectionSelected(string nextSection)

    Layout.preferredWidth: 210
    Layout.fillHeight: true
    color: Colors.mantle
    radius: 14
    border.color: Colors.border
    ColumnLayout {
        anchors {
            fill: parent
            margins: 14
        }
        spacing: 2
        Text {
            text: "Settings"
            font.family: Colors.displayFont
            font.pixelSize: 24
            font.letterSpacing: 2
            color: Colors.bone
            Layout.leftMargin: 6
            Layout.topMargin: 4
            Layout.bottomMargin: 18
        }
        InputField {
            id: settingsSearch
            objectName: "settingsSearch"
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            implicitHeight: 34
            font.pixelSize: 13
            placeholderText: "Search settings…"
            Accessible.name: "Search settings"
            readonly property var matches: {
                const tokens = text.trim().toLowerCase().split(/\s+/).filter(it => it.length);
                return controller.settingsSections.filter(it => tokens.every(token => (it.name + " " + it.words).toLowerCase().indexOf(token) >= 0)).map(it => it.name);
            }
            onAccepted: if (matches.length) matches[0] === "Accounts" ? controller.navigate("accounts") : sectionSelected(matches[0])
        }
        Text {
            visible: !settingsSearch.matches.length
            text: "No settings match"
            color: Colors.subtext
            font.pixelSize: 12
            Layout.leftMargin: 6
        }
        Repeater {
            model: ["Prismarine", "Launcher", "Other"].map(name => ({ group: name, entries: controller.settingsSections.filter(it => it.group === name && settingsSearch.matches.indexOf(it.name) >= 0).map(it => it.name) })).filter(it => it.entries.length)
            delegate: ColumnLayout {
                id: group
                required property var modelData
                required property int index
                Layout.fillWidth: true
                Layout.topMargin: index ? 14 : 0
                spacing: 2
                Text {
                    text: group.modelData.group.toUpperCase()
                    color: Colors.brass
                    font.family: Colors.displayFont
                    font.pixelSize: 10
                    font.letterSpacing: 2
                    Layout.leftMargin: 6
                    Layout.bottomMargin: 4
                }
                Repeater {
                    model: group.modelData.entries
                    delegate: SideNavItem {
                        required property string modelData
                        text: modelData
                        checked: section === modelData
                        onClicked: modelData === "Accounts" ? controller.navigate("accounts") : sectionSelected(modelData)
                    }
                }
            }
        }
        Item {
            Layout.fillHeight: true
        }
        Text {
            text: "Prismarine " + Qt.application.version
            color: Colors.subtext
            font.pixelSize: 11
            Layout.leftMargin: 6
        }
    }
}
