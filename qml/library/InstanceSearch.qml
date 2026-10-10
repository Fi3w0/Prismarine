import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

TextField {
    id: search
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances
    signal moveToBrowser

    text: win.searchText
    Layout.fillWidth: true
    implicitHeight: 40
    placeholderText: "Search instances or Minecraft version…"
    placeholderTextColor: Colors.subtext
    color: Colors.text
    font.pixelSize: 14
    leftPadding: 14
    rightPadding: 36
    Accessible.name: "Search instances"
    background: Rectangle {
        color: Colors.surfaceHi
        radius: 10
        border.color: search.activeFocus ? Colors.accent : Colors.border
    }
    onTextChanged: if (text !== win.searchText)
        win.searchText = text
    Keys.onEscapePressed: {
        clear();
        moveToBrowser();
    }
    Keys.onDownPressed: moveToBrowser()
    ToolButton {
        anchors.right: parent.right
        anchors.verticalCenter: parent.verticalCenter
        visible: search.text.length > 0
        text: "×"
        onClicked: search.clear()
        Accessible.name: "Clear search"
    }
}
