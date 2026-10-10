import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances

    Layout.preferredWidth: win.width >= 1400 ? 300 : 272
    Layout.fillHeight: true
    color: Colors.surface
    Rectangle {
        anchors.left: parent.left
        width: 1
        height: parent.height
        color: Colors.border
    }
    ScrollView {
        id: detailsScroll
        anchors {
            fill: parent
            margins: 20
            bottomMargin: 24
            topMargin: 24
        }
        clip: true
        contentWidth: availableWidth
        ColumnLayout {
            width: detailsScroll.availableWidth
            spacing: 12
            visible: win.hasSelection
            CoverArt {
                Layout.fillWidth: true
                Layout.preferredHeight: 128
                instanceId: win.current.instanceId || ""
                screenshot: win.current.screenshot || ""
                showScreenshot: win.screenshotFor(win.current.instanceId || "", "card")
                cover: win.coverFor(win.current.instanceId || "", "card")
            }
            Text {
                Layout.fillWidth: true
                text: win.current.name || ""
                font.family: Colors.displayFont
                font.pixelSize: 27
                color: Colors.bone
                wrapMode: Text.Wrap
                maximumLineCount: 3
                elide: Text.ElideRight
                RenameTarget { onRenameRequested: win.renameInstance(win.current.instanceId) }
            }
            Flow {
                Layout.fillWidth: true
                spacing: 6
                Chip {
                    text: "MC " + (win.current.version || "?")
                    tint: Colors.text
                }
                Chip {
                    text: (win.current.loader || "") + " " + (win.current.loaderVersion || "")
                    tint: Colors.loaderColor(win.current.loader || "")
                }
                Chip {
                    text: (win.current.mods || 0) + " mods"
                    tint: Colors.accent
                }
            }
            ActionButton {
                Layout.fillWidth: true
                text: "▶  PLAY"
                primary: true
                enabled: win.hasSelection
                onClicked: win.play(win.current.instanceId, win.current.name)
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 132
                radius: 10
                color: Colors.mantle
                GridLayout {
                    anchors.fill: parent
                    anchors.margins: 14
                    columns: 2
                    columnSpacing: 18
                    rowSpacing: 16
                    LibraryFact { Layout.fillWidth: true; label: "Time played"; value: win.current.played || "—" }
                    LibraryFact { Layout.fillWidth: true; label: "Last played"; value: win.current.lastPlayed || "—" }
                    LibraryFact { Layout.fillWidth: true; label: "Memory limit"; value: win.current.memory || "Default" }
                    LibraryFact {
                        Layout.fillWidth: true
                        label: "Play as"
                        value: (instances.accounts.find(it => win.current.accountId ? it.id === win.current.accountId : it.active) || {}).name || "Choose account"
                    }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 2
                LibraryAction { text: "Instance overview"; glyph: "library"; onClicked: win.openInstance(win.current.instanceId) }
                LibraryAction { text: "Manage mods"; glyph: "package"; trailing: (win.current.mods || 0) + "  ›"; onClicked: win.openInstance(win.current.instanceId, "mods") }
                LibraryAction { text: "Duplicate instance"; glyph: "library"; onClicked: win.duplicateInstance(win.current.instanceId) }
                LibraryAction { text: "Rename instance"; glyph: "edit"; trailing: "F2"; onClicked: win.renameInstance(win.current.instanceId) }
                LibraryAction { text: "Card & banner images"; glyph: "edit"; trailing: "›"; onClicked: win.editArtwork(win.current.instanceId) }
                LibraryAction { text: "Move to group"; glyph: "folder"; trailing: (win.current.instanceId && instances.groupOf(win.current.instanceId)) || "›"; onClicked: win.moveToGroup(win.current.instanceId) }
                LibraryAction { text: "Minecraft & loader"; glyph: "settings"; onClicked: win.editVersions(win.current.instanceId) }
                LibraryAction { text: "Instance settings"; glyph: "settings"; onClicked: win.editSettings(win.current.instanceId) }
                LibraryAction { text: "Open folder"; glyph: "folder"; trailing: "↗"; onClicked: instances.openFolder(win.current.instanceId) }
                LibraryAction { text: "Export or share"; glyph: "external"; trailing: "›"; visible: !!win.packExporter; onClicked: win.exportInstance(win.current.instanceId) }
            }
        }
    }
}
