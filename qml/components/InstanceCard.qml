import QtQuick
import QtQuick.Controls

Item {
    id: card
    required property int index
    required property string instanceId
    required property string name
    required property string icon
    required property string version
    required property string loader
    required property int mods
    required property string played
    required property string lastPlayed
    required property string screenshot
    property bool selected: false
    property bool showScreenshot: false
    property string cover: ""
    signal picked
    signal play
    signal open
    signal renameRequested
    signal menuRequested
    signal filesDropped(var urls)
    // Dragging the card toward a sidebar group; positions are in scene coordinates.
    property bool draggable: false
    signal dragStarted(point position)
    signal dragMoved(point position)
    signal dragFinished
    width: GridView.view.cellWidth
    height: GridView.view.cellHeight
    Accessible.role: Accessible.ListItem
    Accessible.name: name + ", Minecraft " + version + ", " + loader
    Accessible.onPressAction: picked()

    CoverArt {
        id: body
        anchors.fill: parent
        anchors.margins: 8
        instanceId: card.instanceId
        screenshot: card.screenshot
        showScreenshot: card.showScreenshot
        cover: card.cover
        scale: hover.hovered ? 1.025 : 1
        Behavior on scale {
            NumberAnimation {
                duration: Colors.animations ? 280 : 0
                easing.type: Easing.OutCubic
            }
        }
        border.width: card.selected ? 2 : 0
        border.color: Colors.accent
        Rectangle {
            anchors {
                left: parent.left
                top: parent.top
                margins: 12
            }
            width: loaderLabel.implicitWidth + 14
            height: 20
            radius: 6
            color: "#cc0a1016"
            Text {
                id: loaderLabel
                anchors.centerIn: parent
                text: card.loader.toUpperCase()
                color: Colors.loaderColor(card.loader)
                font.family: Colors.pixelFont
                font.pixelSize: 8
            }
        }
        Text {
            id: nameLabel
            anchors {
                left: parent.left
                right: parent.right
                bottom: dateTag.top
                margins: 14
                bottomMargin: 12
            }
            text: card.name
            font.family: Colors.displayFont
            font.pixelSize: 20
            lineHeight: 1.05
            color: Colors.artText
            wrapMode: Text.Wrap
            maximumLineCount: 3
            elide: Text.ElideRight
            RenameTarget {
                objectName: "cardRename_" + card.instanceId
                onPicked: card.picked()
                onRenameRequested: card.renameRequested()
            }
        }
        Rectangle {
            id: dateTag
            anchors {
                bottom: parent.bottom
                horizontalCenter: parent.horizontalCenter
                bottomMargin: 12
            }
            width: dateText.implicitWidth + 18
            height: 22
            radius: 6
            color: "#cc0a1016"
            Text {
                id: dateText
                anchors.centerIn: parent
                text: card.lastPlayed
                color: Colors.artText
                font.pixelSize: 12
            }
        }
        Button {
            anchors.centerIn: parent
            width: 48
            height: 48
            opacity: hover.hovered ? 1 : 0
            visible: opacity > 0
            Behavior on opacity { NumberAnimation { duration: Colors.animations ? 220 : 0 } }
            scale: hover.hovered ? 1 : 0.85
            Behavior on scale { NumberAnimation { duration: Colors.animations ? 280 : 0; easing.type: Easing.OutCubic } }
            text: "▶"
            Accessible.name: "Play " + card.name
            onClicked: card.play()
            contentItem: Text {
                text: "▶"
                color: Colors.accentInk
                font.pixelSize: 19
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle {
                radius: 24
                color: Colors.accent
            }
        }
    }
    HoverHandler {
        id: hover
        cursorShape: Qt.PointingHandCursor
    }
    TapHandler {
        onTapped: eventPoint => {
            if (!nameLabel.contains(nameLabel.mapFromItem(card, eventPoint.position))) card.picked();
        }
        onDoubleTapped: eventPoint => {
            if (!nameLabel.contains(nameLabel.mapFromItem(card, eventPoint.position))) card.open();
        }
    }
    DragHandler {
        target: null
        enabled: card.draggable
        // Keeps the grid from turning a card drag into a scroll.
        grabPermissions: PointerHandler.CanTakeOverFromAnything
        onActiveChanged: active ? card.dragStarted(centroid.scenePosition) : card.dragFinished()
        onCentroidChanged: if (active) card.dragMoved(centroid.scenePosition)
    }
    TapHandler {
        acceptedButtons: Qt.RightButton
        onTapped: { card.picked(); card.menuRequested(); }
    }
    FileDropTarget {
        anchors.margins: 8
        label: card.name
        onFilesDropped: urls => card.filesDropped(urls)
    }
}
