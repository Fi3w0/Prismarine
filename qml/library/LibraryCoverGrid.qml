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
    readonly property int columns: Math.max(2, Math.floor(width / (win.preferences.coverSize || (win.preferences.libraryDensity === "compact" ? 170 : 220))))
    FontMetrics { id: titleMetrics; font.family: Colors.displayFont; font.pixelSize: Typography.sectionTitle }
    FontMetrics { id: metadataMetrics; font.pixelSize: Typography.bodySmall }
    FontMetrics { id: captionMetrics; font.pixelSize: Typography.caption }
    cellWidth: Math.floor(width / columns)
    cellHeight: cellWidth - 16 + Math.ceil(titleMetrics.height * 1.15) * 2
        + Math.ceil(metadataMetrics.height) + Math.ceil(captionMetrics.height) + 32
    onColumnsChanged: Qt.callLater(function() {
        if (currentIndex >= 0 && currentIndex < count) positionViewAtIndex(currentIndex, GridView.Contain);
    })
    boundsBehavior: Flickable.StopAtBounds
    ScrollBar.vertical: ScrollBar {}
    delegate: InstanceCard {
        showBadge: win.preferences.showCoverBadges
        selected: index === win.selected
        keyboardSelected: selected && grid.activeFocus
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
    activeFocusOnTab: true
    // A controller leaves the grid at its edges; arrow keys keep moving the selection within it.
    Keys.onLeftPressed: event => { if (win.gamepadKey && win.selected % columns === 0) event.accepted = false; else win.select(win.selected - 1); }
    Keys.onRightPressed: event => { if (win.gamepadKey && (win.selected % columns === columns - 1 || win.selected >= count - 1)) event.accepted = false; else win.select(win.selected + 1); }
    Keys.onUpPressed: event => { if (win.gamepadKey && win.selected < columns) event.accepted = false; else win.select(win.selected - columns); }
    Keys.onDownPressed: event => { if (win.gamepadKey && Math.floor(win.selected / columns) === Math.floor((count - 1) / columns)) event.accepted = false; else win.select(win.selected + columns); }
}
