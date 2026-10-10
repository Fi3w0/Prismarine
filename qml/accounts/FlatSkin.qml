import QtQuick
import "SkinParts.js" as SkinParts

Item {
    id: flat
    property string skin: ""
    property bool slim: false
    property bool legacy: false
    property bool layers: true
    Item {
        width: 16
        height: 32
        anchors.centerIn: parent
        scale: Math.min(flat.width / 24, flat.height / 38)
        Repeater {
            model: SkinParts.parts(flat.slim, flat.legacy, flat.layers)
            delegate: Image {
                required property var modelData
                x: 8 + modelData.x - width / 2
                y: 16 - modelData.y - height / 2
                width: modelData.w + 2 * (modelData.inflate || 0)
                height: modelData.h + 2 * (modelData.inflate || 0)
                source: flat.skin
                sourceClipRect: Qt.rect(modelData.u + modelData.d, modelData.v + modelData.d, modelData.w, modelData.h)
                smooth: false
                mirror: modelData.mirror || false
            }
        }
    }
}
