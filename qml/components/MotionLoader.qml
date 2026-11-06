import QtQuick

Loader {
    id: host
    property bool backwards: false
    readonly property bool motionEnabled: Colors.animations && host.visible
        && !!host.Window.window && host.Window.window.visible
        && host.Window.window.visibility !== Window.Minimized
    function finishMotion() {
        entrance.stop();
        host.opacity = 1;
        offset.x = 0;
    }
    onMotionEnabledChanged: if (!motionEnabled) finishMotion()
    onLoaded: {
        finishMotion();
        if (motionEnabled) entrance.start();
    }
    transform: Translate { id: offset }
    ParallelAnimation {
        id: entrance
        NumberAnimation { target: host; property: "opacity"; from: 0; to: 1; duration: Colors.motionEnterDuration; easing.type: Easing.OutCubic }
        NumberAnimation { target: offset; property: "x"; from: host.backwards ? -Colors.motionSlideDistance : Colors.motionSlideDistance; to: 0; duration: Colors.motionPageDuration; easing.type: Easing.OutCubic }
    }
}
