import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: home
    required property var controller
    Layout.fillWidth: true
    spacing: 12
    Text { text: qsTr("Home sections"); color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold }
    Text { Layout.fillWidth: true; text: qsTr("Keep the sections you use. Continue playing always stays at the top."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
    GridLayout {
        Layout.fillWidth: true
        columns: width < 620 ? 1 : 2
        columnSpacing: 24
        rowSpacing: 8
        Repeater {
            model: [
                {key: "recent", name: qsTr("Recently played")},
                {key: "servers", name: qsTr("Favourite servers")},
                {key: "worlds", name: qsTr("Worlds")},
                {key: "stats", name: qsTr("Library statistics")},
                {key: "news", name: qsTr("News")},
                {key: "playtime", name: qsTr("Playtime")}
            ]
            delegate: ToggleSwitch {
                required property var modelData
                objectName: "homeSection_" + modelData.key
                Layout.fillWidth: true
                text: modelData.name
                checked: home.controller.preferences.homeSections.indexOf(modelData.key) >= 0
                onToggled: {
                    const sections = home.controller.preferences.homeSections;
                    home.controller.preferences.homeSections = checked ? sections.concat([modelData.key]) : sections.filter(key => key !== modelData.key);
                }
            }
        }
    }
}
