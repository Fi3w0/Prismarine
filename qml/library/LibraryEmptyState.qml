import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ColumnLayout {
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances

    anchors.centerIn: parent
    width: Math.min(parent.width - 32, 360)
    visible: instances.count === 0
    spacing: 14
    Text {
        Layout.fillWidth: true
        text: instances.totalCount > 0 ? "No matching instances" : "Your library is empty"
        font.family: Colors.displayFont
        font.pixelSize: 24
        color: Colors.bone
        horizontalAlignment: Text.AlignHCenter
        wrapMode: Text.Wrap
    }
    Text {
        Layout.fillWidth: true
        text: instances.totalCount > 0 ? "Try a different name, version, or loader." : "Create your first instance to get started.\n" + instances.instanceDir
        color: Colors.subtext
        font.pixelSize: 13
        wrapMode: Text.WrapAnywhere
        horizontalAlignment: Text.AlignHCenter
    }
    ActionButton {
        Layout.alignment: Qt.AlignHCenter
        text: instances.totalCount > 0 ? "Clear filters" : "Create instance"
        onClicked: instances.totalCount > 0 ? win.clearFilters() : win.createInstance()
    }
}
