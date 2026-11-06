import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebar
    required property var controller
    required property string section
    signal sectionSelected(string nextSection)

    Layout.preferredWidth: 230
    Layout.fillHeight: true
    color: Colors.surfaceHi
    radius: 20
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
            font.pixelSize: Typography.emptyTitle
            font.letterSpacing: 2
            color: Colors.bone
            Layout.leftMargin: 6
            Layout.topMargin: 4
            Layout.bottomMargin: 18
        }
        InputField {
            id: settingsSearch
            objectName: sidebar.visible ? "settingsSearch" : ""
            Layout.fillWidth: true
            Layout.bottomMargin: 10
            implicitHeight: 34
            font.pixelSize: Typography.body
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
            font.pixelSize: Typography.bodySmall
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
                    font.pixelSize: Typography.badge
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
                        background: Rectangle {
                            radius: 12
                            color: parent.checked ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.16) : parent.hovered ? Colors.surface : "transparent"
                            border.color: parent.visualFocus ? Colors.accent : "transparent"
                            Rectangle { anchors { left: parent.left; top: parent.top; bottom: parent.bottom; margins: 1 } width: 3; radius: 2; color: Colors.accent; visible: parent.parent.checked }
                        }
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
            font.pixelSize: Typography.caption
            Layout.leftMargin: 6
        }
    }
}
