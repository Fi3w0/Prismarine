import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// The current skin, Prismarine's saved skins, and the cape picker.
Rectangle {
    id: card
    required property var controller
    required property var profile
    required property string chosen
    required property string chosenCape
    signal skinChosen(string file)
    signal capeChosen(string id)
    readonly property var manager: controller.accountManager
    readonly property var capes: profile.capes || []
    color: Colors.surface
    radius: 14
    border.color: Colors.border
    implicitHeight: body.implicitHeight + 40

    component Tile: AbstractButton {
        id: tile
        property string skin: ""
        property bool selected: false
        implicitWidth: 76
        implicitHeight: 96
        hoverEnabled: true
        background: Rectangle {
            radius: 10
            color: tile.selected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12) : tile.hovered ? Colors.surfaceHi : Colors.mantle
            border.width: tile.selected ? 2 : 1
            border.color: tile.selected || tile.visualFocus ? Colors.accent : Colors.border
        }
        contentItem: ColumnLayout {
            spacing: 4
            SkinAvatar {
                Layout.alignment: Qt.AlignHCenter
                Layout.topMargin: 8
                visible: tile.skin !== ""
                skin: tile.skin
                size: 40
            }
            Text {
                Layout.alignment: Qt.AlignHCenter
                visible: tile.skin === ""
                Layout.topMargin: 14
                text: "+"
                color: Colors.subtext
                font.pixelSize: 26
            }
            Item { Layout.fillHeight: true }
            Text {
                Layout.fillWidth: true
                Layout.bottomMargin: 6
                horizontalAlignment: Text.AlignHCenter
                text: tile.text
                color: tile.selected ? Colors.text : Colors.subtext
                font.pixelSize: 10
                elide: Text.ElideRight
            }
        }
        HoverHandler { cursorShape: Qt.PointingHandCursor }
    }

    ColumnLayout {
        id: body
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            Text {
                Layout.fillWidth: true
                text: "Skins"
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: 20
                font.letterSpacing: 2
            }
            ActionButton {
                text: "Upload skin…"
                implicitWidth: 120
                implicitHeight: 32
                font.pixelSize: 12
                onClicked: skinDialog.open()
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 10
            Tile {
                text: "Current"
                skin: card.profile.skin || ""
                selected: card.chosen === ""
                Accessible.name: "Current skin"
                onClicked: card.skinChosen("")
            }
            Repeater {
                model: card.manager.savedSkins
                delegate: Tile {
                    required property var modelData
                    text: modelData.name
                    skin: modelData.url
                    selected: card.chosen === modelData.file
                    Accessible.name: "Saved skin " + modelData.name
                    onClicked: card.skinChosen(modelData.file)
                    TapHandler {
                        acceptedButtons: Qt.RightButton
                        onTapped: if (card.manager.removeSkin(parent.modelData.file) && card.chosen === parent.modelData.file) card.skinChosen("")
                    }
                    ToolTip.visible: hovered
                    ToolTip.delay: 600
                    ToolTip.text: "Right-click to remove from the library"
                }
            }
            Tile {
                text: "Add"
                Accessible.name: "Add a skin"
                onClicked: skinDialog.open()
            }
        }
        Text {
            text: "Cape"
            color: Colors.subtext
            font.pixelSize: 12
            Layout.topMargin: 4
        }
        Flow {
            Layout.fillWidth: true
            spacing: 10
            Repeater {
                model: [{ alias: "No cape", id: "", url: "" }].concat(card.capes)
                delegate: AbstractButton {
                    id: capeTile
                    required property var modelData
                    readonly property bool selected: card.chosenCape === modelData.id
                    implicitWidth: 64
                    implicitHeight: 92
                    hoverEnabled: true
                    Accessible.name: modelData.alias
                    onClicked: card.capeChosen(modelData.id)
                    ToolTip.visible: hovered
                    ToolTip.delay: 400
                    ToolTip.text: modelData.alias + (modelData.id === (card.profile.cape || "") ? " · equipped" : "")
                    background: Rectangle {
                        radius: 10
                        color: capeTile.selected ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12) : capeTile.hovered ? Colors.surfaceHi : Colors.mantle
                        border.width: capeTile.selected ? 2 : 1
                        border.color: capeTile.selected || capeTile.visualFocus ? Colors.accent : Colors.border
                    }
                    contentItem: ColumnLayout {
                        spacing: 4
                        Item {
                            Layout.alignment: Qt.AlignHCenter
                            Layout.topMargin: 8
                            implicitWidth: 30
                            implicitHeight: 48
                            // The outward artwork of the cape: 10×16 pixels at (1, 1) of Mojang's 64×32 texture.
                            Image {
                                id: capeArt
                                anchors.fill: parent
                                visible: capeTile.modelData.url !== ""
                                source: capeTile.modelData.url
                                sourceClipRect: Qt.rect(1, 1, 10, 16)
                                smooth: false
                                asynchronous: true
                            }
                            Text {
                                anchors.centerIn: parent
                                visible: capeTile.modelData.url === "" || capeArt.status !== Image.Ready
                                text: capeTile.modelData.url === "" ? "∅" : "…"
                                color: Colors.subtext
                                font.pixelSize: 18
                            }
                        }
                        Item { Layout.fillHeight: true }
                        Text {
                            Layout.fillWidth: true
                            Layout.bottomMargin: 6
                            horizontalAlignment: Text.AlignHCenter
                            text: capeTile.modelData.alias
                            color: capeTile.selected ? Colors.text : Colors.subtext
                            font.pixelSize: 9
                            elide: Text.ElideRight
                        }
                    }
                    HoverHandler { cursorShape: Qt.PointingHandCursor }
                }
            }
        }
    }
    FileDialog {
        id: skinDialog
        title: "Add a Minecraft skin"
        nameFilters: ["Skin images (*.png)"]
        onAccepted: {
            const file = card.manager.addSkin(selectedFile);
            if (file)
                card.skinChosen(file);
        }
    }
}
