import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: bar
    required property var controller
    // Qt maps Ctrl shortcuts to Command on macOS.
    readonly property string searchShortcut: Qt.platform.os === "osx" ? "⌘K" : "Ctrl+K"

    objectName: "topBar"
    Layout.fillWidth: true
    Layout.preferredHeight: 60
    color: Colors.base
    Button {
        id: search
        objectName: "topSearch"
        anchors.centerIn: parent
        width: Math.min(520, parent.width - 2 * (account.width + 32))
        height: 40
        leftPadding: 12
        rightPadding: 8
        hoverEnabled: true
        Accessible.name: "Search everything"
        onClicked: bar.controller.openPalette()
        background: Rectangle {
            radius: 10
            color: search.hovered ? Colors.surfaceHi : Colors.surface
            border.color: search.activeFocus ? Colors.accent : Colors.outline
        }
        contentItem: RowLayout {
            spacing: 10
            LineIcon {
                name: "search"
                tint: Colors.subtext
                Layout.preferredWidth: 18
                Layout.preferredHeight: 18
            }
            Text {
                Layout.fillWidth: true
                text: "Search everything"
                color: Colors.subtext
                font.pixelSize: Typography.control
                elide: Text.ElideRight
            }
            Rectangle {
                implicitWidth: shortcut.implicitWidth + 16
                implicitHeight: 24
                radius: 6
                color: Colors.surfaceHi
                Text {
                    id: shortcut
                    anchors.centerIn: parent
                    text: bar.searchShortcut
                    color: Colors.subtext
                    font.pixelSize: Typography.bodySmall
                }
            }
        }
    }
    AccountSwitcher {
        id: account
        anchors {
            right: parent.right
            rightMargin: 16
            verticalCenter: parent.verticalCenter
        }
        controller: bar.controller
    }
}
