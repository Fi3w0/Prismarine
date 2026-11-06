import QtQuick
import QtQuick.Controls

Window {
    id: host
    required property var preferences
    width: 840
    height: 760
    visible: true
    SettingsDraft { id: draft; objectName: "selectorDraft"; preferences: host.preferences }
    ColourEditor { x: 20; y: 20; width: 480; preferences: draft }
    Button {
        objectName: "selectorApply"
        x: 560; y: 600; width: 120; height: 40
        text: "Apply"
        enabled: draft.dirty
        onClicked: draft.apply()
    }
}
