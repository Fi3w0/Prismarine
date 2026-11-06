import QtQuick
import QtQuick.Controls

// Context and overflow menus in the app palette. Items use ThemedMenuItem.
Menu {
    id: menu
    padding: 6
    implicitWidth: 230
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Colors.animations ? Colors.motionFeedbackDuration : 0; easing.type: Easing.OutCubic } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Colors.animations ? Colors.motionFeedbackDuration : 0; easing.type: Easing.InCubic } }
    background: Rectangle {
        implicitWidth: menu.implicitWidth
        radius: 12
        color: Colors.surface
        border.color: Colors.border
    }
    delegate: ThemedMenuItem {}
}
