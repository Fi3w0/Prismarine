import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Settings → Experimental: features that can misbehave, each off by default.
ColumnLayout {
    id: panel
    required property var controller
    spacing: 14
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: body.implicitHeight + 36
        radius: 14
        color: Qt.rgba(Colors.warning.r, Colors.warning.g, Colors.warning.b, 0.07)
        border.color: Qt.rgba(Colors.warning.r, Colors.warning.g, Colors.warning.b, 0.4)
        ColumnLayout {
            id: body
            anchors { fill: parent; margins: 18 }
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    RowLayout {
                        Text { text: "Multi-account play"; color: Colors.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Chip { text: "UNSAFE"; tint: Colors.warning }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: "Adds a ▾ next to Play on an instance to launch it with another signed-in account at the same time."
                        color: Colors.subtext
                        font.pixelSize: 13
                        wrapMode: Text.Wrap
                    }
                }
                ToggleSwitch {
                    objectName: "multiAccountToggle"
                    checked: panel.controller.preferences.multiAccount
                    enabled: !!panel.controller.altLaunch
                    onToggled: panel.controller.preferences.multiAccount = checked
                }
            }
            Text {
                Layout.fillWidth: true
                text: "How it works: Prism allows one running game per instance, so each extra account gets a hidden copy named “<instance>.alt-<account>”, grouped under “Multi-account (unsafe)” in Prism. "
                    + "Before every launch the copy is refreshed from the original: mods, resource packs and shaders as hard links (no extra space), config copied over. Worlds are never shared — play together on a server or LAN. "
                    + "The original instance is only read. Risks: double memory use, config changes made in a copy are replaced, and a mod that writes into its own jar file would affect both. Use at your own risk."
                color: Colors.subtext
                font.pixelSize: 12
                lineHeight: 1.25
                wrapMode: Text.Wrap
            }
        }
    }
}
