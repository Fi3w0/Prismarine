import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Rectangle {
    id: toast
    property real availableWidth: parent.width
    property bool error: false
    function show(message, isError = false) {
        toastText.text = message;
        error = isError;
        opacity = 1;
        toastTimer.restart();
    }
    anchors {
        horizontalCenter: parent.horizontalCenter
        bottom: parent.bottom
        bottomMargin: 24
    }
    width: Math.min(availableWidth - 80, toastText.implicitWidth + 40)
    height: toastText.implicitHeight + 28
    radius: 12
    color: Colors.surfaceHi
    border.color: error ? Colors.danger : Colors.accent
    opacity: 0
    Behavior on opacity {
        NumberAnimation {
            duration: Colors.animations ? 180 : 0
        }
    }
    Text {
        id: toastText
        anchors.centerIn: parent
        width: Math.min(implicitWidth, toast.availableWidth - 120)
        color: Colors.text
        font.pixelSize: 14
        wrapMode: Text.Wrap
    }
    Timer {
        id: toastTimer
        interval: toast.error ? 5000 : 3000
        onTriggered: toast.opacity = 0
    }
}
