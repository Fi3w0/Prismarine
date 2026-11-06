import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ListView {
    id: rows
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances
    objectName: "instanceRows"
    anchors.fill: parent
    visible: win.rowsView
    clip: true
    model: instances
    currentIndex: win.selected
    spacing: 6
    ScrollBar.vertical: ScrollBar {}
    delegate: ItemDelegate {
        id: entry
        required property int index
        required property string instanceId
        required property string name
        required property var model
        required property string version
        required property string loader
        required property int mods
        required property string played
        width: rows.width
        height: win.preferences.libraryDensity === "compact" ? 58 : 74
        onClicked: {
            win.select(index);
            rows.forceActiveFocus();
        }
        onDoubleClicked: win.openInstance(instanceId)
        DragHandler {
            target: null
            enabled: win.width >= 1200
            grabPermissions: PointerHandler.CanTakeOverFromAnything
            onActiveChanged: active ? win.beginDrag({ instanceId: entry.instanceId, name: entry.name }, centroid.scenePosition) : win.endDrag()
            onCentroidChanged: if (active) win.moveDrag(centroid.scenePosition)
        }
        TapHandler {
            acceptedButtons: Qt.RightButton
            onTapped: { win.select(entry.index); win.showInstanceMenu(entry.instanceId, entry.name); }
        }
        FileDropTarget {
            radius: 10
            label: entry.name
            onFilesDropped: urls => win.handleDrop(urls, entry.instanceId)
        }
        background: Rectangle {
            radius: 10
            color: entry.hovered || entry.index === win.selected ? Colors.surfaceHi : Colors.surface
            border.color: entry.index === win.selected ? Colors.accent : Colors.border
        }
        contentItem: RowLayout {
            spacing: 12
            InstanceIcon {
                size: 40
                icon: entry.model.icon
                name: entry.name
                loader: entry.loader
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: entry.name
                    elide: Text.ElideRight
                    color: Colors.text
                    font.pixelSize: Typography.control
                    font.weight: Font.DemiBold
                    RenameTarget {
                        objectName: "rowRename_" + entry.instanceId
                        onPicked: { win.select(entry.index); rows.forceActiveFocus(); }
                        onRenameRequested: win.renameInstance(entry.instanceId)
                    }
                }
                Text {
                    text: entry.version + " · " + entry.loader
                    color: Colors.loaderColor(entry.loader)
                    font.pixelSize: Typography.bodySmall
                }
            }
            Text {
                text: entry.mods + " mods\n" + entry.played
                color: Colors.subtext
                font.pixelSize: Typography.caption
                horizontalAlignment: Text.AlignRight
            }
        }
    }
    activeFocusOnTab: true
    // A controller leaves the list at its ends.
    Keys.onUpPressed: event => { if (win.gamepadKey && win.selected <= 0) event.accepted = false; else win.select(win.selected - 1); }
    Keys.onDownPressed: event => { if (win.gamepadKey && win.selected >= count - 1) event.accepted = false; else win.select(win.selected + 1); }
    Keys.onReturnPressed: if (win.hasSelection)
        win.play(win.current.instanceId, win.current.name)
}
