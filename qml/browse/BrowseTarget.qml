import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: target
    required property var controller
    required property string targetId
    required property string contentType
    readonly property var info: controller.instances.getById(targetId)
    readonly property bool packs: contentType === "modpack"
    signal targetSelected(string id)
    Layout.fillWidth: true
    implicitHeight: targetContent.implicitHeight + 24
    radius: 12
    color: Colors.surface
    border.color: Colors.border
    ColumnLayout {
        id: targetContent
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Text {
                text: target.packs ? qsTr("Install as") : qsTr("Installing to")
                color: Colors.subtext
                font.pixelSize: Typography.body
            }
            SelectBox {
                objectName: "browseTargetPicker"
                Layout.fillWidth: true
                visible: !target.packs
                model: target.controller.instances.allInstances
                textRole: "name"
                currentIndex: model.findIndex(it => it.instanceId === target.targetId)
                displayText: currentIndex < 0 ? qsTr("Choose an instance…") : currentText
                Accessible.name: qsTr("Install target")
                onActivated: target.targetSelected(model[currentIndex].instanceId)
            }
            Text {
                Layout.fillWidth: true
                visible: target.packs
                text: qsTr("A new instance")
                color: Colors.text
                font.pixelSize: Typography.body
            }
        }
        Text {
            objectName: "browseCompatibility"
            Layout.fillWidth: true
            visible: !target.packs
            text: !target.info.version ? qsTr("Choose an instance to find compatible content.")
                : qsTr("Minecraft %1").arg(target.info.version)
                  + (target.contentType === "mod" && target.info.loader ? " · " + target.info.loader : "")
                  + qsTr(" · Compatible versions only")
            color: Colors.subtext
            font.pixelSize: Typography.bodySmall
            wrapMode: Text.Wrap
        }
    }
}
