import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: preview
    property string skin: ""
    property string variant: "CLASSIC"
    property bool layers: true
    property string cape: ""
    property bool elytra: false
    readonly property bool legacy: texture.sourceSize.height > 0 && texture.sourceSize.height * 2 === texture.sourceSize.width
    readonly property bool slim: variant.toUpperCase() === "SLIM" && !legacy
    readonly property bool hardware: GraphicsInfo.api !== GraphicsInfo.Software && GraphicsInfo.api !== GraphicsInfo.Unknown
    color: Colors.mantle
    radius: 12
    border.color: Colors.border
    Image { id: texture; source: preview.skin; visible: false; asynchronous: true }
    Rectangle {
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 240)
        height: width
        radius: width / 2
        color: Qt.alpha(Colors.accent, 0.045)
    }
    Loader {
        id: sceneLoader
        anchors.fill: parent
        anchors.margins: 12
        anchors.bottomMargin: 52
        active: texture.status === Image.Ready
        sourceComponent: preview.hardware ? scene3D : scene2D
    }
    Component { id: scene3D; SkinScene { skin: preview.skin; slim: preview.slim; legacy: preview.legacy; layers: preview.layers; cape: preview.cape; elytra: preview.elytra } }
    Component { id: scene2D; FlatSkin { skin: preview.skin; slim: preview.slim; legacy: preview.legacy; layers: preview.layers } }
    Text {
        anchors.centerIn: parent
        visible: texture.status !== Image.Ready
        text: texture.status === Image.Loading ? "Loading skin…" : "No skin available"
        color: Colors.subtext
        font.pixelSize: 14
    }
    RowLayout {
        anchors { bottom: parent.bottom; left: parent.left; right: parent.right; margins: 16 }
        Text { Layout.fillWidth: true; text: preview.hardware ? "Drag to rotate" : "Front view"; color: Colors.subtext; font.pixelSize: 12 }
        ActionButton {
            visible: preview.hardware && preview.cape !== ""
            implicitWidth: 80; implicitHeight: 32
            text: preview.elytra ? "Elytra ✓" : "Elytra"
            checked: preview.elytra
            Accessible.name: "Show the cape as an elytra"
            onClicked: preview.elytra = !preview.elytra
        }
        ActionButton {
            visible: preview.hardware
            implicitWidth: 74; implicitHeight: 32; text: "Turn ↻"
            Accessible.name: "Turn the model around"
            onClicked: if (sceneLoader.item) sceneLoader.item.turn()
        }
        ActionButton { implicitWidth: 88; implicitHeight: 32; text: preview.layers ? "Layers ✓" : "Layers"; checked: preview.layers; onClicked: preview.layers = !preview.layers }
    }
}
