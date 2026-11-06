import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: panel
    objectName: "libraryDetails"
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances

    Layout.preferredWidth: win.width >= 1600 ? 340 : win.width >= 1400 ? 320 : 272
    Layout.fillHeight: true
    Layout.topMargin: 20
    Layout.rightMargin: 20
    Layout.bottomMargin: 20
    radius: 16
    color: Colors.surface

    ColumnLayout {
        anchors { verticalCenter: parent.verticalCenter; left: parent.left; right: parent.right; margins: 20 }
        visible: !panel.win.hasSelection
        spacing: 8
        Text { Layout.fillWidth: true; text: qsTr("Select an instance"); color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: Typography.sectionTitle; wrapMode: Text.Wrap }
        Text { Layout.fillWidth: true; text: qsTr("Choose a cover to see its details and actions."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
    }
    ScrollView {
        id: detailsScroll
        objectName: "libraryDetailsScroll"
        anchors { fill: parent; margins: 20 }
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: detailsScroll.availableWidth
            spacing: 14
            visible: panel.win.hasSelection
            AbstractButton {
                objectName: "selectedCover"
                Layout.fillWidth: true
                Layout.preferredHeight: width * 0.56
                Accessible.name: qsTr("Open %1").arg(panel.win.current.name || "")
                onClicked: panel.win.openInstance(panel.win.current.instanceId)
                contentItem: CoverArt {
                    instanceId: panel.win.current.instanceId || ""
                    screenshot: panel.win.current.screenshot || ""
                    showScreenshot: panel.win.screenshotFor(instanceId, "card")
                    cover: panel.win.coverFor(instanceId, "card")
                }
                background: Rectangle { anchors.fill: parent; anchors.margins: -3; color: "transparent"; radius: 15; border.color: parent.visualFocus ? Colors.accent : "transparent"; border.width: 2 }
            }
            Text {
                Layout.fillWidth: true
                text: panel.win.current.name || ""
                textFormat: Text.PlainText
                font.family: Colors.displayFont
                font.pixelSize: Typography.detailTitle
                color: Colors.bone
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
                RenameTarget {
                    ToolTip.text: (panel.win.current.name || "") + "\n" + qsTr("Double-click to rename · F2")
                    onRenameRequested: panel.win.renameInstance(panel.win.current.instanceId)
                }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Chip { text: "MC " + (panel.win.current.version || "?"); tint: Colors.text }
                Chip { text: [panel.win.current.loader, panel.win.current.loaderVersion].filter(part => part).join(" "); tint: Colors.loaderColor(panel.win.current.loader || "") }
                Chip { text: qsTr("%1 mods").arg(panel.win.current.mods || 0); tint: Colors.accent }
            }
            ActionButton {
                objectName: "selectedInstancePlay"
                Layout.fillWidth: true
                text: "▶  PLAY"
                primary: true
                enabled: panel.win.hasSelection
                onClicked: panel.win.play(panel.win.current.instanceId, panel.win.current.name)
            }
            GridLayout {
                Layout.fillWidth: true
                Layout.topMargin: 6
                Layout.bottomMargin: 6
                columns: 2
                columnSpacing: 16
                rowSpacing: 16
                LibraryFact { Layout.fillWidth: true; label: qsTr("Time played"); value: panel.win.current.played || "—" }
                LibraryFact { Layout.fillWidth: true; label: qsTr("Last played"); value: panel.win.current.lastPlayed || "—" }
                LibraryFact { Layout.fillWidth: true; label: qsTr("Memory limit"); value: panel.win.current.memory || qsTr("Default") }
                LibraryFact {
                    Layout.fillWidth: true
                    label: qsTr("Play as")
                    value: (panel.instances.accounts.find(it => panel.win.current.accountId ? it.id === panel.win.current.accountId : it.active) || {}).name || qsTr("Choose account")
                }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                LibraryAction { objectName: "selectedInstanceMods"; text: qsTr("Manage mods"); glyph: "package"; trailing: (panel.win.current.mods || 0) + "  ›"; onClicked: panel.win.openInstance(panel.win.current.instanceId, "mods") }
                LibraryAction { objectName: "selectedInstanceWorlds"; text: qsTr("Worlds & screenshots"); glyph: "world"; onClicked: panel.win.openInstance(panel.win.current.instanceId, "worlds") }
                LibraryAction { objectName: "selectedInstanceSettings"; text: qsTr("Instance settings"); glyph: "settings"; onClicked: panel.win.editSettings(panel.win.current.instanceId) }
            }
            RowLayout {
                Layout.fillWidth: true
                spacing: 6
                LibraryShortcut { objectName: "selectedInstanceDuplicate"; text: qsTr("Duplicate"); glyph: "copy"; onClicked: panel.win.duplicateInstance(panel.win.current.instanceId) }
                LibraryShortcut { objectName: "selectedInstanceRename"; text: qsTr("Rename"); glyph: "edit"; onClicked: panel.win.renameInstance(panel.win.current.instanceId) }
                LibraryShortcut { objectName: "selectedInstanceCover"; text: qsTr("Cover"); glyph: "image"; onClicked: panel.win.editArtwork(panel.win.current.instanceId) }
                LibraryShortcut { objectName: "selectedInstanceGroup"; text: qsTr("Group"); glyph: "folder"; onClicked: panel.win.moveToGroup(panel.win.current.instanceId) }
            }
            TextLink {
                id: moreButton
                objectName: "selectedInstanceMore"
                text: qsTr("More actions…")
                tint: Colors.subtext
                onClicked: moreActions.popup(moreButton, 0, moreButton.height)
            }
        }
    }
    ThemedMenu {
        id: moreActions
        objectName: "selectedInstanceMoreMenu"
        ThemedMenuItem { text: qsTr("Instance overview"); onTriggered: panel.win.openInstance(panel.win.current.instanceId) }
        ThemedMenuItem { text: qsTr("Minecraft & loader"); onTriggered: panel.win.editVersions(panel.win.current.instanceId) }
        ThemedMenuItem { text: qsTr("Open folder"); onTriggered: panel.instances.openFolder(panel.win.current.instanceId) }
        ThemedMenuItem { text: qsTr("Export or share"); visible: !!panel.win.packExporter; height: visible ? implicitHeight : 0; onTriggered: panel.win.exportInstance(panel.win.current.instanceId) }
    }
}
