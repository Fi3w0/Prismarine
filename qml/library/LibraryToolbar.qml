import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

RowLayout {
    id: toolbar
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances

    Layout.fillWidth: true
    spacing: 10
    Text {
        text: "Library"
        color: Colors.bone
        font.family: Colors.displayFont
        font.pixelSize: Typography.pageTitle
        font.letterSpacing: 3
    }
    Item {
        Layout.fillWidth: true
    }
    SelectBox {
        id: sort
        objectName: "sortPicker"
        model: ["Last played", "Name", "Mod count"]
        Layout.preferredWidth: toolbar.width < 400 ? 112 : 136
        Layout.minimumWidth: 112
        implicitHeight: 32
        currentIndex: ["recent", "name", "mods"].indexOf(win.preferences.sortOrder)
        onActivated: win.preferences.sortOrder = ["recent", "name", "mods"][currentIndex]
        contentItem: Text {
            text: sort.displayText
            color: Colors.text
            font.pixelSize: Typography.bodySmall
            verticalAlignment: Text.AlignVCenter
            leftPadding: 10
            rightPadding: 24
        }
        background: Rectangle {
            color: Colors.surface
            radius: 8
            border.color: Colors.border
        }
    }
    ActionButton {
        text: "▦"
        compact: true
        implicitWidth: 36
        implicitHeight: 34
        checked: !win.rowsView
        onClicked: win.preferences.libraryView = "covers"
        ToolTip.visible: hovered
        ToolTip.text: "Cover view"
        Accessible.name: "Cover view"
    }
    ActionButton {
        text: "☰"
        compact: true
        implicitWidth: 36
        implicitHeight: 34
        checked: win.rowsView
        onClicked: win.preferences.libraryView = "rows"
        ToolTip.visible: hovered
        ToolTip.text: "List view"
        Accessible.name: "List view"
    }
}
