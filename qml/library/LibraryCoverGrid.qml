import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

GridView {
    id: grid
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances
    objectName: "coverGrid"
    anchors.fill: parent
    anchors.margins: -8
    clip: true
    visible: !win.rowsView
    focus: true
    model: instances
    currentIndex: win.selected
    readonly property int columns: Math.max(2, Math.floor(width / 174))
    cellWidth: Math.floor(width / columns)
    cellHeight: Math.round((cellWidth - 16) * 1.5) + 16
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    delegate: InstanceCard {
        selected: index === win.selected
        showScreenshot: win.screenshotFor(instanceId, "card")
        cover: win.coverFor(instanceId, "card")
        onPicked: {
            win.select(index);
            grid.forceActiveFocus();
        }
        onPlay: win.play(instanceId, name)
        onOpen: win.openInstance(instanceId)
        onRenameRequested: win.renameInstance(instanceId)
        onMenuRequested: win.showInstanceMenu(instanceId, name)
        onFilesDropped: urls => win.handleDrop(urls, instanceId)
        draggable: win.width >= 1200
        onDragStarted: position => win.beginDrag({ instanceId: instanceId, name: name }, position)
        onDragMoved: position => win.moveDrag(position)
        onDragFinished: win.endDrag()
    }
    Keys.onReturnPressed: if (win.hasSelection)
        win.play(win.current.instanceId, win.current.name)
    Keys.onEnterPressed: if (win.hasSelection)
        win.play(win.current.instanceId, win.current.name)
    Keys.onLeftPressed: win.select(win.selected - 1)
    Keys.onRightPressed: win.select(win.selected + 1)
    Keys.onUpPressed: win.select(win.selected - columns)
    Keys.onDownPressed: win.select(win.selected + columns)
}
