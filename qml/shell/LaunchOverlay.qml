import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Prismarine's own launch screen: the steps Prism reports while signing in and preparing
// the game, then the game's own milestones. Prism may still show its small dialog too.
Popup {
    id: overlay
    objectName: "launchOverlay"
    required property var controller
    readonly property var progress: controller.launchProgress
    readonly property string instanceId: progress ? progress.instanceId : ""
    readonly property var info: controller.instances.getById(instanceId).instanceId ? controller.instances.getById(instanceId)
        : controller.instances.copies().find(it => it.instanceId === instanceId) || ({})
    readonly property string stage: progress ? progress.stage : ""
    readonly property bool failed: stage === "failed"
    readonly property bool ready: stage === "ready"
    property var diagnosis: ({})
    readonly property var findings: diagnosis.findings || []
    readonly property var finding: findings.length ? findings[0] : ({})
    onInstanceIdChanged: diagnosis = ({})
    onStageChanged: if (stage !== "failed") diagnosis = ({})
    readonly property var steps: [
        { key: "signin", label: "Sign in" },
        { key: "files", label: "Game files" },
        { key: "java", label: "Start Java" },
        { key: "game", label: "Load Minecraft" }
    ]
    // Index of the step in progress; all done once ready.
    readonly property string stepStage: failed && progress ? progress.lastStage : stage
    readonly property int current: ready ? steps.length : Math.max(0, steps.findIndex(it => it.key === stepStage))
    function formatTime(secs) {
        return Math.floor(secs / 60) + ":" + String(secs % 60).padStart(2, "0");
    }
    function finish() {
        close();
        if (progress) progress.dismiss();
    }

    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round((parent.height - height) / 2)
    width: Math.min(560, parent.width - 64)
    height: Math.min(implicitHeight, parent.height - 48)
    modal: true
    focus: true
    padding: 0
    closePolicy: Popup.CloseOnEscape
    Overlay.modal: Rectangle { color: Colors.light ? Qt.rgba(0.08, 0.14, 0.17, 0.3) : Qt.rgba(0.01, 0.03, 0.05, 0.6) }
    enter: Transition {
        ParallelAnimation {
            NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Colors.animations ? Colors.motionEnterDuration : 0; easing.type: Easing.OutCubic }
            NumberAnimation { property: "scale"; from: 0.985; to: 1; duration: Colors.animations ? Colors.motionEnterDuration : 0; easing.type: Easing.OutCubic }
        }
    }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Colors.animations ? Colors.motionExitDuration : 0; easing.type: Easing.InCubic } }
    background: Rectangle { radius: 18; color: Colors.surface; border.color: overlay.failed ? Colors.danger : Colors.border }

    // Leaves the finished state on screen briefly, then gets out of the way.
    Timer {
        interval: 1800
        running: overlay.visible && overlay.ready
        onTriggered: overlay.finish()
    }
    // The elapsed clock ticks even when no new log line arrives.
    Timer {
        interval: 1000
        repeat: true
        running: overlay.visible && !overlay.ready && !overlay.failed
        onTriggered: clock.seconds = overlay.progress ? overlay.progress.elapsedSecs : 0
    }

    contentItem: ColumnLayout {
        spacing: 0
        // Banner with the instance's hero picture.
        Item {
            Layout.fillWidth: true
            Layout.preferredHeight: 128
            clip: true
            HeroBackdrop {
                anchors.fill: parent
                anchors.margins: 1
                radius: 17
                cover: overlay.controller.coverFor(overlay.info.altOf || overlay.instanceId, "hero")
                screenshot: overlay.info.screenshot || ""
                showScreenshot: overlay.controller.screenshotFor(overlay.info.altOf || overlay.instanceId, "hero")
            }
            Rectangle {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom }
                height: 40
                gradient: Gradient {
                    GradientStop { position: 0; color: "transparent" }
                    GradientStop { position: 1; color: Colors.surface }
                }
            }
            RowLayout {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 22; bottomMargin: 16 }
                spacing: 14
                InstanceIcon {
                    size: 52
                    icon: overlay.info.icon || ""
                    name: overlay.info.name || ""
                    loader: overlay.info.loader || ""
                }
                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: 2
                    Text {
                        text: overlay.failed ? "LAUNCH STOPPED" : overlay.ready ? "READY" : "LAUNCHING"
                        color: overlay.failed ? Colors.danger : Colors.brass
                        font.family: Colors.displayFont
                        font.pixelSize: Typography.bodySmall
                        font.letterSpacing: 2.5
                    }
                    Text {
                        Layout.fillWidth: true
                        text: overlay.info.name || overlay.instanceId
                        color: Colors.bone
                        font.family: Colors.displayFont
                        font.pixelSize: Typography.dialogTitle
                        elide: Text.ElideRight
                    }
                    Text {
                        visible: !!text
                        text: (overlay.info.loader ? overlay.info.loader + " · " : "") + (overlay.info.version ? "Minecraft " + overlay.info.version : "")
                              + (overlay.controller.session && overlay.controller.session.account ? " · as " + overlay.controller.session.account : "")
                        color: Colors.subtext
                        font.pixelSize: Typography.bodySmall
                    }
                }
                Text {
                    id: clock
                    property int seconds: 0
                    Layout.alignment: Qt.AlignTop
                    text: overlay.formatTime(seconds)
                    color: Colors.subtext
                    font.pixelSize: Typography.body
                    font.family: "monospace"
                }
            }
        }

        ScrollView {
            id: contentScroll
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.minimumHeight: 0
            Layout.preferredHeight: recoveryContent.implicitHeight + 30
            contentWidth: availableWidth
            contentHeight: recoveryContent.implicitHeight + 30
            clip: true
            ColumnLayout {
                id: recoveryContent
                width: contentScroll.availableWidth - 44
                x: 22
                y: 8
                spacing: 16
                // Stepper
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 0
                    Repeater {
                        model: overlay.steps
                        delegate: RowLayout {
                            id: step
                            required property var modelData
                            required property int index
                            objectName: "launchStep_" + index
                            readonly property bool done: index < overlay.current
                            readonly property bool active: index === overlay.current && !overlay.ready
                            Layout.fillWidth: index < overlay.steps.length - 1
                            spacing: 0
                            ColumnLayout {
                                spacing: 6
                                Rectangle {
                                    Layout.alignment: Qt.AlignHCenter
                                    implicitWidth: 26
                                    implicitHeight: 26
                                    radius: 13
                                    color: step.done ? Colors.accent : step.active && overlay.failed ? Qt.rgba(Colors.danger.r, Colors.danger.g, Colors.danger.b, 0.18) : Colors.inset
                                    border.width: step.active ? 2 : 1
                                    border.color: step.active ? (overlay.failed ? Colors.danger : Colors.accent) : step.done ? Colors.accent : Colors.border
                                    Text {
                                        anchors.centerIn: parent
                                        visible: step.done || (step.active && overlay.failed)
                                        text: step.done ? "✓" : "!"
                                        color: step.done ? Colors.accentInk : Colors.danger
                                        font.pixelSize: Typography.body
                                        font.weight: Font.Bold
                                    }
                                    // Spinning arc on the active step.
                                    Canvas {
                                        id: spinner
                                        anchors.fill: parent
                                        visible: step.active && !overlay.failed
                                        property real angle: 0
                                        readonly property color stroke: Colors.accent
                                        onStrokeChanged: requestPaint()
                                        onAngleChanged: requestPaint()
                                        onPaint: {
                                            const ctx = getContext("2d");
                                            ctx.reset();
                                            ctx.strokeStyle = stroke;
                                            ctx.lineWidth = 2.5;
                                            ctx.lineCap = "round";
                                            ctx.beginPath();
                                            ctx.arc(width / 2, height / 2, width / 2 - 5, angle, angle + Math.PI * 1.2);
                                            ctx.stroke();
                                        }
                                        NumberAnimation on angle {
                                            running: spinner.visible && Colors.animations
                                            from: 0
                                            to: Math.PI * 2
                                            duration: 900
                                            loops: Animation.Infinite
                                        }
                                    }
                                }
                                Text {
                                    Layout.alignment: Qt.AlignHCenter
                                    text: step.modelData.label
                                    color: step.active || step.done ? Colors.text : Colors.subtext
                                    font.pixelSize: Typography.bodySmall
                                    font.weight: step.active ? Font.DemiBold : Font.Normal
                                }
                            }
                            Rectangle {
                                visible: step.index < overlay.steps.length - 1
                                Layout.fillWidth: true
                                Layout.alignment: Qt.AlignTop
                                Layout.topMargin: 12
                                Layout.leftMargin: 6
                                Layout.rightMargin: 6
                                implicitHeight: 2
                                radius: 1
                                color: step.done ? Colors.accent : Colors.border
                            }
                        }
                    }
                }
                // What Prism is doing right now
                Text {
                    objectName: "launchDetail"
                    Layout.fillWidth: true
                    text: overlay.progress ? overlay.progress.detail : ""
                    color: overlay.failed ? Colors.danger : Colors.text
                    font.pixelSize: Typography.control
                    wrapMode: Text.Wrap
                    maximumLineCount: 3
                    elide: Text.ElideRight
                }
                Rectangle {
                    Layout.fillWidth: true
                    visible: overlay.failed && overlay.findings.length > 0
                    implicitHeight: recoveryBody.implicitHeight + 24
                    radius: 10
                    color: Colors.inset
                    border.color: Colors.border
                    ColumnLayout {
                        id: recoveryBody
                        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
                        spacing: 6
                        Text {
                            objectName: "launchFindingTitle"
                            Layout.fillWidth: true
                            text: overlay.finding.title || ""
                            textFormat: Text.PlainText
                            color: Colors.text
                            font.pixelSize: Typography.body
                            font.weight: Font.DemiBold
                            wrapMode: Text.Wrap
                            maximumLineCount: 2
                            elide: Text.ElideRight
                        }
                        Text {
                            objectName: "launchFindingDetail"
                            Layout.fillWidth: true
                            text: overlay.finding.detail || ""
                            textFormat: Text.PlainText
                            color: Colors.subtext
                            font.pixelSize: Typography.bodySmall
                            wrapMode: Text.Wrap
                            maximumLineCount: 3
                            elide: Text.ElideRight
                        }
                        ActionButton {
                            objectName: "launchInstallFix"
                            Layout.fillWidth: true
                            visible: !!overlay.finding.project
                            text: qsTr("Install Fabric API…")
                            primary: true
                            onClicked: if (overlay.controller.reviewLaunchFix(overlay.instanceId, overlay.finding.project)) overlay.finish()
                        }
                        TextLink {
                            objectName: "launchRecoveryAction"
                            visible: !!overlay.finding.action && !overlay.finding.project
                            text: overlay.finding.action === "settings" ? qsTr("Open instance settings →")
                                : overlay.finding.action === "browse" ? qsTr("Find %1 in Browse →").arg(overlay.finding.query)
                                : qsTr("Open the Mods tab →")
                            onClicked: {
                                const id = overlay.instanceId, action = overlay.finding.action, query = overlay.finding.query;
                                overlay.finish();
                                if (action === "settings") overlay.controller.editSettings(id);
                                else if (action === "browse") overlay.controller.browseFor(id, query);
                                else overlay.controller.openInstance(id, "mods");
                            }
                        }
                    }
                }
                TextLink {
                    objectName: "launchViewLog"
                    visible: overlay.failed && !(overlay.progress && overlay.progress.abortRequested)
                    text: overlay.findings.length > 1 ? qsTr("View log and all %1 findings →").arg(overlay.findings.length) : qsTr("View log →")
                    onClicked: {
                        const id = overlay.instanceId;
                        overlay.finish();
                        overlay.controller.openInstance(id, "logs");
                    }
                }
                // Overall progress
                Rectangle {
                    id: track
                    Layout.fillWidth: true
                    implicitHeight: 6
                    radius: 3
                    color: Colors.inset
                    clip: true
                    Rectangle {
                        width: track.width * (overlay.progress ? overlay.progress.progress : 0)
                        height: parent.height
                        radius: 3
                        color: overlay.failed ? Colors.danger : Colors.accent
                        Behavior on width { NumberAnimation { duration: Colors.animations ? 500 : 0; easing.type: Easing.OutCubic } }
                    }
                    // A soft highlight sweeps along while work is under way.
                    Rectangle {
                        visible: !overlay.ready && !overlay.failed && Colors.animations
                        width: 80
                        height: parent.height
                        x: -width
                        opacity: 0.35
                        gradient: Gradient {
                            orientation: Gradient.Horizontal
                            GradientStop { position: 0; color: "transparent" }
                            GradientStop { position: 0.5; color: Colors.bone }
                            GradientStop { position: 1; color: "transparent" }
                        }
                        NumberAnimation on x {
                            running: overlay.visible && !overlay.ready && !overlay.failed && Colors.animations
                            from: -80
                            to: track.width
                            duration: 1400
                            loops: Animation.Infinite
                        }
                    }
                }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 10
                    Text {
                        Layout.fillWidth: true
                        text: overlay.failed && overlay.progress && overlay.progress.abortRequested ? "Stopped by you."
                            : overlay.failed ? qsTr("Review the log or open Prism for more details.")
                            : overlay.controller.desktop && overlay.controller.desktop.hidePrismProgress ? "Prism Launcher does the work in the background."
                            : "Prism Launcher does the work and may show its own small window too."
                        color: Colors.subtext
                        font.pixelSize: Typography.caption
                        wrapMode: Text.Wrap
                    }
                    // One click to stop Prism's own "Please wait…" window from showing next time (KDE).
                    TextLink {
                        objectName: "hidePrismWindowLink"
                        visible: !!overlay.controller.desktop && overlay.controller.desktop.kdeAvailable && !overlay.controller.desktop.hidePrismProgress
                        text: "Keep Prism's window minimized"
                        pixelSize: Typography.bodySmall
                        onClicked: if (overlay.controller.desktop.setHidePrismProgress(true))
                            overlay.controller.notify("Prism's progress window will stay minimized from now on")
                    }
                    ActionButton {
                        visible: overlay.controller.prismShortcuts !== false && (overlay.failed || (overlay.stage === "waiting" && clock.seconds >= 20))
                        text: "Open Prism"
                        implicitWidth: 120
                        onClicked: overlay.controller.instances.openPrism()
                    }
                    ActionButton {
                        objectName: "launchOverlayAbort"
                        visible: !overlay.failed && !overlay.ready
                        text: "Abort"
                        danger: true
                        implicitWidth: 100
                        onClicked: overlay.controller.abortLaunch()
                    }
                    ActionButton {
                        objectName: "launchOverlayHide"
                        text: overlay.failed || overlay.ready ? "Close" : "Hide"
                        implicitWidth: 100
                        primary: overlay.ready
                        onClicked: overlay.failed || overlay.ready ? overlay.finish() : overlay.close()
                    }
                }
            }
        }
    }
}
