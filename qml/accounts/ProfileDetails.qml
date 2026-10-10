import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: card
    required property var controller
    property var profile: ({})
    signal removeRequested
    // Instances that pick this account explicitly, plus those following the default when it is the default.
    readonly property int usedBy: controller.instances.allInstances.filter(it => it.accountId === profile.id || (profile.active && !it.accountId)).length
    readonly property int instanceCount: controller.instances.allInstances.length
    color: Colors.surface
    radius: 14
    border.color: Colors.border
    implicitHeight: body.implicitHeight + 40
    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 14
        Text {
            text: "Details"
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: 20
            font.letterSpacing: 2
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 24
            rowSpacing: 10
            Text { text: "Status"; color: Colors.subtext; font.pixelSize: 12 }
            Text {
                Layout.fillWidth: true
                text: !card.profile.id ? "—" : card.profile.signedIn ? "✓ Signed in, token valid" : "Sign-in expired · refresh in Prism"
                color: !card.profile.id ? Colors.subtext : card.profile.signedIn ? Colors.success : Colors.warning
                font.pixelSize: 12
            }
            Text { text: "Account type"; color: Colors.subtext; font.pixelSize: 12 }
            Text { Layout.fillWidth: true; text: card.profile.type === "MSA" ? "Microsoft" : card.profile.type || "—"; color: Colors.text; font.pixelSize: 12 }
            Text { text: "UUID"; color: Colors.subtext; font.pixelSize: 12 }
            TextEdit {
                Layout.fillWidth: true
                text: card.profile.id || "—"
                readOnly: true
                selectByMouse: true
                wrapMode: TextEdit.WrapAnywhere
                color: Colors.text
                font.family: Colors.pixelFont
                font.pixelSize: 9
            }
            Text { text: "Used by"; color: Colors.subtext; font.pixelSize: 12 }
            Text {
                Layout.fillWidth: true
                text: card.usedBy === card.instanceCount && card.instanceCount ? "All " + card.instanceCount + " instances" + (card.profile.active ? " (default account)" : "")
                    : card.usedBy + (card.usedBy === 1 ? " instance" : " instances") + (card.profile.active ? " (default account)" : "")
                color: Colors.text
                font.pixelSize: 12
                wrapMode: Text.Wrap
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
        Flow {
            Layout.fillWidth: true
            spacing: 8
            ActionButton {
                text: card.profile.active ? "Default ✓" : "Use this account"
                primary: !card.profile.active
                enabled: !!card.profile.id && !card.profile.active
                implicitWidth: 130
                implicitHeight: 34
                font.pixelSize: 12
                onClicked: if (card.controller.accountManager.setDefault(card.profile.id)) card.controller.notify("Playing as " + card.profile.name)
            }
            ActionButton {
                text: "Refresh sign-in ↗"
                implicitWidth: 130
                implicitHeight: 34
                font.pixelSize: 12
                enabled: !!card.profile.id
                ToolTip.visible: hovered
                ToolTip.delay: 500
                ToolTip.text: "Opens Prism Launcher, which handles Microsoft sign-in"
                onClicked: if (card.controller.instances.openPrism()) card.controller.notify("Opening Prism to refresh the sign-in…")
            }
            ActionButton {
                text: "Change username ↗"
                implicitWidth: 140
                implicitHeight: 34
                font.pixelSize: 12
                onClicked: Qt.openUrlExternally("https://www.minecraft.net/msaprofile/mygames/editprofile")
            }
            ActionButton {
                text: "Remove account"
                danger: true
                implicitWidth: 130
                implicitHeight: 34
                font.pixelSize: 12
                enabled: !!card.profile.id
                onClicked: card.removeRequested()
            }
        }
    }
}
