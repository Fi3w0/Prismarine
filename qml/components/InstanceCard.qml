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
    property bool showBadge: true
    property bool selected: false
    property bool keyboardSelected: false
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
        objectName: "cardArt_" + card.instanceId
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 8 }
        height: width
        instanceId: card.instanceId
        screenshot: card.screenshot
        showScreenshot: card.showScreenshot
        cover: card.cover
        scale: hover.hovered ? 1.015 : 1
        Behavior on scale {
            NumberAnimation { duration: Colors.animations ? Colors.motionFeedbackDuration : 0; easing.type: Easing.OutCubic }
        }
        Rectangle {
            visible: card.showBadge
            anchors { left: parent.left; top: parent.top; margins: 12 }
            width: loaderBadge.implicitWidth + 20
            height: 26
            radius: 13
            color: "#d90a1016"
            Row {
                id: loaderBadge
                anchors.centerIn: parent
                spacing: 6
                Rectangle {
                    anchors.verticalCenter: parent.verticalCenter
                    width: 6; height: 6; radius: 3
                    color: Colors.loaderColor(card.loader, true)
                }
                Text { text: card.loader || qsTr("Vanilla"); color: Colors.artText; font.pixelSize: Typography.bodySmall }
            }
        }
        Button {
            id: playButton
            objectName: "cardPlay_" + card.instanceId
            anchors.centerIn: parent
            width: 48
            height: 48
            readonly property bool shown: hover.hovered || card.keyboardSelected || activeFocus
            opacity: shown ? 1 : 0
            visible: opacity > 0
            activeFocusOnTab: card.selected
            Behavior on opacity { NumberAnimation { duration: Colors.animations ? Colors.motionFeedbackDuration : 0 } }
            text: "▶"
            Accessible.name: qsTr("Play %1").arg(card.name)
            onClicked: card.play()
            contentItem: Text {
                text: "▶"
                color: Colors.accentInk
                font.pixelSize: Typography.cardTitle
                horizontalAlignment: Text.AlignHCenter
                verticalAlignment: Text.AlignVCenter
            }
            background: Rectangle { radius: 24; color: Colors.accent; border.width: playButton.visualFocus ? 2 : 0; border.color: Colors.bone }
        }
        Rectangle {
            anchors.fill: parent
            radius: body.radius
            color: "transparent"
            border.width: card.selected ? 2 : 0
            border.color: Colors.accent
        }
    }
    Text {
        id: nameLabel
        objectName: "cardTitle_" + card.instanceId
        anchors { left: body.left; right: body.right; top: body.bottom; topMargin: 10; leftMargin: 4; rightMargin: 4 }
        text: card.name
        textFormat: Text.PlainText
        font.family: Colors.displayFont
        font.pixelSize: Typography.sectionTitle
        lineHeight: 1.15
        color: Colors.bone
        wrapMode: Text.Wrap
        maximumLineCount: 2
        elide: Text.ElideRight
        RenameTarget {
            objectName: "cardRename_" + card.instanceId
            ToolTip.text: card.name + "\n" + qsTr("Double-click to rename · F2")
            onPicked: card.picked()
            onRenameRequested: card.renameRequested()
        }
    }
    Text {
        id: metadata
        anchors { left: nameLabel.left; right: nameLabel.right; top: nameLabel.bottom; topMargin: 2 }
        text: [card.loader, card.version].filter(part => part).join(" ")
        color: Colors.subtext
        font.pixelSize: Typography.bodySmall
        elide: Text.ElideRight
    }
    Text {
        anchors { left: nameLabel.left; right: nameLabel.right; top: metadata.bottom; topMargin: 2 }
        text: !card.lastPlayed || card.lastPlayed.toLowerCase() === "never" ? qsTr("Not played yet") : qsTr("Last played %1").arg(card.lastPlayed)
        color: Colors.subtext
        font.pixelSize: Typography.caption
        elide: Text.ElideRight
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
