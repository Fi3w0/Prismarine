import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Settings → Launcher mode: Stable or Full, removing Prism, and optional features.
ColumnLayout {
    id: panel
    objectName: "launcherModeSettings"
    required property var controller
    readonly property var mode: controller.launcherMode
    readonly property var preferences: controller.preferences
    readonly property bool full: !!mode && mode.fullAvailable
    readonly property string prismPath: mode ? mode.prismProgram : ""
    Layout.fillWidth: true
    spacing: 24
    onVisibleChanged: if (visible && mode) mode.refresh()

    component Heading: Text {
        Layout.fillWidth: true
        color: Colors.text
        font.pixelSize: Typography.bodyLarge
        font.weight: Font.DemiBold
    }
    component ModeCard: Rectangle {
        id: card
        property string title
        property string detail
        property bool current: false
        property bool fullOnly: false
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        Layout.fillHeight: true
        implicitHeight: cardContent.implicitHeight + 32
        radius: Colors.controlRadius + 4
        color: Colors.surface
        border.width: current ? 2 : 1
        border.color: current ? Colors.accent : Colors.border
        ColumnLayout {
            id: cardContent
            anchors { left: parent.left; right: parent.right; top: parent.top; margins: 16 }
            spacing: 8
            RowLayout {
                spacing: 10
                Text { text: card.title; color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold }
                FullModeBadge { visible: card.current; text: qsTr("In use"); }
            }
            Text { Layout.fillWidth: true; text: card.detail; color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
        }
    }

    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        ModeCard {
            objectName: "stableModeCard"
            title: qsTr("Stable")
            current: !panel.full
            detail: qsTr("Uses your installed Prism Launcher. Both launchers stay installed. Features marked Full mode only stay off.")
        }
        ModeCard {
            objectName: "fullModeCard"
            title: qsTr("Full")
            current: panel.full
            detail: qsTr("Prismarine runs on its own Prism-based engine and keeps using Prism's folders, so one launcher is enough.")
        }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Text {
            Layout.fillWidth: true
            text: panel.full ? qsTr("The Prismarine engine is active.") : qsTr("Full mode isn't available in this version yet. The engine that powers it is still being built.")
            color: Colors.subtext
            font.pixelSize: Typography.bodySmall
            wrapMode: Text.Wrap
        }
        ActionButton {
            objectName: "updateToFullMode"
            text: panel.full ? qsTr("Using Full mode") : qsTr("Update to Full mode")
            implicitWidth: 190
            primary: !panel.full
            enabled: !panel.full
            onClicked: fullModeDialog.open()
        }
    }

    Heading { text: qsTr("What Full mode adds") }
    Repeater {
        model: panel.mode ? panel.mode.fullFeatures : []
        delegate: RowLayout {
            id: feature
            required property var modelData
            Layout.fillWidth: true
            spacing: 16
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                Text { Layout.fillWidth: true; text: feature.modelData.title; color: Colors.text; font.pixelSize: Typography.body; wrapMode: Text.Wrap }
                Text { Layout.fillWidth: true; text: feature.modelData.detail; color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
            }
            FullModeBadge { text: feature.modelData.available ? qsTr("Active") : panel.full ? qsTr("Not in this engine yet") : qsTr("Full mode only") }
        }
    }

    Heading { text: qsTr("Prism Launcher") }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 5
            RowLayout {
                spacing: 10
                Text { text: qsTr("Remove Prism Launcher"); color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold }
                FullModeBadge { visible: !panel.full }
            }
            Text {
                objectName: "prismLocationText"
                Layout.fillWidth: true
                text: (panel.prismPath ? qsTr("Found at %1.").arg(panel.prismPath) : qsTr("Prism Launcher wasn't found on this system."))
                    + " " + qsTr("Keep Prism and Prismarine together, or remove only the Prism app once Full mode is running. Your instances, worlds and accounts stay in their folders.")
                textFormat: Text.PlainText
                color: Colors.subtext
                font.pixelSize: Typography.bodySmall
                wrapMode: Text.Wrap
            }
        }
        ActionButton {
            objectName: "removePrismButton"
            text: qsTr("Remove Prism…")
            implicitWidth: 150
            onClicked: removePrismDialog.open()
        }
    }

    SettingsToggleRow {
        objectName: "prismShortcutsRow"
        title: qsTr("Prism Launcher shortcuts")
        detail: qsTr("Show links that open Prism's window. Sign-in and CurseForge installs without a key still need it in Stable mode.")
        value: panel.preferences.prismShortcuts
        onToggled: value => panel.preferences.prismShortcuts = value
    }

    Heading { text: qsTr("Start in") }
    SettingsChoiceRow {
        objectName: "startInterfaceRow"
        title: qsTr("Interface")
        detail: qsTr("Handheld is a preview: it switches to full screen now and when Prismarine starts. Controller navigation isn't built yet. Choose Desktop or press F11 to leave full screen.")
        choices: [{ label: qsTr("Desktop"), value: "desktop" }, { label: qsTr("Handheld preview"), value: "handheld" }]
        value: panel.mode ? panel.mode.interfaceMode : panel.preferences.startInterface
        onChosen: value => {
            panel.preferences.startInterface = value;
            if (panel.mode) panel.mode.interfaceMode = value;
        }
    }

    ConfirmDialog {
        id: fullModeDialog
        objectName: "fullModeDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        title: qsTr("Full mode isn't ready yet")
        message: qsTr("Full mode needs Prismarine's own engine, and this version doesn't include one. You can keep playing in Stable mode, and nothing changes until an engine is installed.")
        confirmText: qsTr("Check again")
        onConfirmed: {
            panel.mode.refresh();
            panel.controller.notify(panel.full ? qsTr("Full mode engine found") : qsTr("No engine found yet. Stable mode stays on."));
        }
    }
    ConfirmDialog {
        id: removePrismDialog
        objectName: "removePrismDialog"
        parent: Overlay.overlay
        anchors.centerIn: parent
        title: panel.full ? qsTr("Remove Prism Launcher") : qsTr("Keep Prism for now")
        message: (panel.full ? qsTr("Remove the app with your package manager or Prism's uninstaller.")
                             : qsTr("Stable mode starts games through Prism Launcher, so removing it now would stop games from launching. You can remove it once Full mode is running."))
            + " " + qsTr("Your instances, worlds and accounts are kept in their own folders.")
        confirmText: panel.prismPath ? qsTr("Open Prism's folder") : qsTr("OK")
        onConfirmed: {
            if (!panel.prismPath) return;
            const folder = panel.prismPath.substring(0, panel.prismPath.lastIndexOf("/"));
            Qt.openUrlExternally("file:///" + folder.replace(/^\/+/, ""));
        }
    }
}
