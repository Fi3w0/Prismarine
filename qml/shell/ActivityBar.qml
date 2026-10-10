import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// One status strip for long work anywhere in the app: installs, pack imports and exports,
// mod updates, and the running game. Shows the most important active task.
Rectangle {
    id: bar
    required property var controller
    readonly property var task: {
        const c = controller;
        if (c.installer.state === "downloading")
            return { label: "Installing content", progress: c.installer.progress, cancel: () => c.installer.cancel() };
        if (c.packImporter.state === "fetching" || c.packImporter.state === "downloading" || c.packImporter.state === "extracting")
            return { label: c.packImporter.state === "extracting" ? "Unpacking modpack" : "Downloading modpack files", progress: c.packImporter.state === "extracting" ? -1 : c.packImporter.progress, cancel: () => c.packImporter.cancel() };
        if (c.updater && c.updater.state === "updating")
            return { label: "Updating content", progress: c.updater.progress, cancel: () => c.updater.cancel() };
        if (c.packExporter && c.packExporter.state === "exporting")
            return { label: "Exporting " + c.packExporter.name, progress: c.packExporter.progress, cancel: null };
        if (c.updater && c.updater.state === "checking")
            return { label: "Checking content for updates", progress: -1, cancel: null };
        if (c.session && c.session.active && c.session.state !== "exited" && c.page !== "session")
            return { label: "Playing " + c.session.name, progress: -2, cancel: null, open: "session" };
        return null;
    }
    objectName: "activityBar"
    Layout.fillWidth: true
    Layout.preferredHeight: task ? 38 : 0
    visible: Layout.preferredHeight > 0
    clip: true
    color: Colors.mantle
    Behavior on Layout.preferredHeight { NumberAnimation { duration: Colors.animations ? 180 : 0; easing.type: Easing.OutCubic } }
    Rectangle {
        anchors.top: parent.top
        width: parent.width
        height: 1
        color: Colors.border
    }
    RowLayout {
        anchors {
            fill: parent
            leftMargin: 18
            rightMargin: 18
        }
        spacing: 12
        Rectangle {
            width: 8
            height: 8
            radius: 4
            color: Colors.accent
            SequentialAnimation on opacity {
                running: Colors.animations && bar.visible
                loops: Animation.Infinite
                NumberAnimation { to: 0.3; duration: 800 }
                NumberAnimation { to: 1; duration: 800 }
            }
        }
        Text {
            text: bar.task ? bar.task.label : ""
            color: Colors.text
            font.pixelSize: 12
            font.weight: Font.DemiBold
        }
        ProgressBar {
            id: meter
            Layout.fillWidth: true
            Layout.maximumWidth: 420
            visible: !!bar.task && bar.task.progress > -2
            indeterminate: !!bar.task && bar.task.progress < 0
            value: bar.task ? Math.max(0, bar.task.progress) : 0
            background: Rectangle {
                implicitHeight: 6
                radius: 3
                color: Colors.surfaceHi
            }
            contentItem: Item {
                implicitHeight: 6
                Rectangle {
                    width: meter.indeterminate ? parent.width * 0.3 : meter.visualPosition * parent.width
                    height: parent.height
                    radius: 3
                    color: Colors.accent
                    NumberAnimation on x {
                        running: meter.indeterminate && meter.visible
                        loops: Animation.Infinite
                        from: 0
                        to: meter.width * 0.7
                        duration: 1100
                        easing.type: Easing.InOutSine
                    }
                }
            }
        }
        Text {
            visible: !!bar.task && bar.task.progress >= 0
            text: bar.task ? Math.round(bar.task.progress * 100) + "%" : ""
            color: Colors.subtext
            font.pixelSize: 11
        }
        Item {
            Layout.fillWidth: true
        }
        TextLink {
            visible: !!bar.task && !!bar.task.open
            text: "Open"
            onClicked: bar.controller.navigate(bar.task.open)
        }
        TextLink {
            visible: !!bar.task && !!bar.task.cancel
            text: "Cancel"
            tint: Colors.subtext
            underline: false
            onClicked: bar.task.cancel()
        }
    }
}
