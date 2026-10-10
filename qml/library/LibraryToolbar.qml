import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

RowLayout {
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances

    Layout.fillWidth: true
    spacing: 10
    Text {
        text: "Library"
        color: Colors.bone
        font.family: Colors.displayFont
        font.pixelSize: 30
        font.letterSpacing: 3
    }
    Item {
        Layout.fillWidth: true
    }
    Text {
        text: "SORT"
        font.pixelSize: 10
        font.letterSpacing: 1.5
        font.weight: Font.Bold
        color: Colors.subtext
    }
    SelectBox {
        id: sort
        objectName: "sortPicker"
        model: ["Last played", "Name", "Mod count"]
        implicitWidth: 136
        implicitHeight: 32
        currentIndex: ["recent", "name", "mods"].indexOf(win.preferences.sortOrder)
        onActivated: win.preferences.sortOrder = ["recent", "name", "mods"][currentIndex]
        contentItem: Text {
            text: sort.displayText
            color: Colors.text
            font.pixelSize: 12
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
        implicitHeight: 34
        checked: win.rowsView
        onClicked: win.preferences.libraryView = "rows"
        ToolTip.visible: hovered
        ToolTip.text: "List view"
        Accessible.name: "List view"
    }
}
