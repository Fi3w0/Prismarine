import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ItemDelegate {
    id: entry
    required property var controller
    required property var instance
    // The sidebar that draws the drag ghost; entries without one cannot be dragged.
    property var dragHost: null
    objectName: "sidebarEntry_" + instance.instanceId
    implicitHeight: 36
    onClicked: controller.selectId(instance.instanceId)
    onDoubleClicked: controller.openInstance(instance.instanceId)
    opacity: dragHost && dragHost.draggingId === instance.instanceId ? 0.45 : 1
    background: Rectangle {
        radius: 6
        color: entry.hovered || entry.controller.current.instanceId === entry.instance.instanceId ? Colors.surfaceHi : "transparent"
    }
    contentItem: RowLayout {
        spacing: 10
        InstanceIcon {
            size: 22
            icon: entry.instance.icon || ""
            name: entry.instance.name || ""
            loader: entry.instance.loader || ""
        }
        Text {
            Layout.fillWidth: true
            text: entry.instance.name
            color: Colors.text
            font.pixelSize: 13
            elide: Text.ElideRight
            font.weight: entry.controller.current.instanceId === entry.instance.instanceId ? Font.Bold : Font.Normal
        }
    }
    DragHandler {
        target: null
        enabled: !!entry.dragHost
        onActiveChanged: active ? entry.dragHost.beginDrag(entry.instance, centroid.scenePosition) : entry.dragHost.endDrag()
        onCentroidChanged: if (active) entry.dragHost.moveDrag(centroid.scenePosition)
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: entry.controller.showInstanceMenu(entry.instance.instanceId, entry.instance.name)
    }
    FileDropTarget {
        radius: 6
        onFilesDropped: urls => entry.controller.handleDrop(urls, entry.instance.instanceId)
    }
}
