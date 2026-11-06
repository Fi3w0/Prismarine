import QtQuick
import QtQuick.Controls

// Every dialog and menu the main window opens, in one place.
Item {
    id: dialogs
    required property var controller
    readonly property alias rename: renamePopup
    readonly property alias duplicate: duplicatePopup
    readonly property alias newInstance: newInstancePopup
    readonly property alias instanceSettings: instanceSettingsPopup
    readonly property alias installReview: installReviewPopup
    readonly property alias exportPack: exportPackPopup
    readonly property alias packImport: packImportPopup
    readonly property alias accountNeeded: accountNeededPopup
    readonly property alias alreadyRunning: alreadyRunningPopup
    readonly property alias launchWarning: launchWarningPopup
    readonly property alias multiAccountWarning: multiAccountWarningPopup
    readonly property alias profilePrompt: profilePromptPopup
    readonly property alias drop: dropPopup
    readonly property alias groupName: groupNamePopup
    readonly property alias moveGroup: moveGroupPopup
    readonly property alias instanceMenu: instanceMenuPopup
    readonly property alias commandPalette: commandPalettePopup
    readonly property alias launchOverlay: launchOverlayPopup
    readonly property alias artwork: artworkPopup
    readonly property alias deleteGroup: deleteGroupPopup

    RenameInstanceDialog { id: renamePopup; controller: dialogs.controller; anchors.centerIn: Overlay.overlay }
    DuplicateDialog { id: duplicatePopup; controller: dialogs.controller; anchors.centerIn: Overlay.overlay }
    NewInstanceDialog {
        id: newInstancePopup
        controller: dialogs.controller
        anchors.centerIn: parent
    }

    InstanceSettingsDialog {
        id: instanceSettingsPopup
        controller: dialogs.controller
        anchors.centerIn: parent
    }
    InstallReviewDialog {
        id: installReviewPopup
        controller: dialogs.controller
        anchors.centerIn: parent
    }
    ExportDialog {
        id: exportPackPopup
        controller: dialogs.controller
        anchors.centerIn: parent
    }
    PackImportDialog {
        id: packImportPopup
        controller: dialogs.controller
        anchors.centerIn: parent
    }
    ConfirmDialog {
        id: accountNeededPopup
        objectName: "accountNeeded"
        anchors.centerIn: Overlay.overlay
        title: "Add an account first"
        message: "Minecraft needs a Microsoft account to start. Add one in Accounts, then press Play again."
        confirmText: "Go to Accounts"
        onConfirmed: dialogs.controller.navigate("accounts")
    }
    ConfirmDialog {
        id: alreadyRunningPopup
        objectName: "alreadyRunning"
        property string instanceId: ""
        property string name: ""
        anchors.centerIn: Overlay.overlay
        title: name + " is already running"
        message: "Prism can run each instance only once. To play it with a second account at the same time, use the ▾ next to Play on the instance page"
            + (dialogs.controller.preferences.multiAccount ? "." : " after turning on Settings → Experimental → Multi-account play.")
        confirmText: "Go to Now playing"
        onConfirmed: {
            if (dialogs.controller.session) dialogs.controller.session.start(instanceId);
            dialogs.controller.navigate("session");
        }
    }
    ConfirmDialog {
        id: launchWarningPopup
        objectName: "launchWarning"
        property string instanceId: ""
        property string name: ""
        anchors.centerIn: Overlay.overlay
        title: "Launch with mod errors?"
        message: (dialogs.controller.modHealth ? dialogs.controller.modHealth.errors : 0) + " problems were found in this instance's mods, such as duplicates or missing dependencies. The game will probably stop while loading. Fix them in the Mods tab, or launch anyway."
        confirmText: "Launch anyway"
        danger: true
        onConfirmed: dialogs.controller.play(instanceId, name, true)
    }
    ConfirmDialog {
        id: multiAccountWarningPopup
        objectName: "multiAccountWarning"
        property string instanceId: ""
        property string account: ""
        anchors.centerIn: Overlay.overlay
        width: 520
        title: "Play as " + account + "? (unsafe)"
        message: "Prism runs one game per instance, so Prismarine makes a separate copy for " + account + " and refreshes it from the original before every launch. "
            + "Mods and packs are shared as hard links, config is copied over the copy's own each time, and worlds are never shared. "
            + "The original is only read, but two games at once double memory use, and a mod that writes into its own jar would affect both. Use at your own risk."
        confirmText: "I understand, launch"
        danger: true
        onConfirmed: {
            dialogs.controller.launching.multiAccountAccepted = true;
            dialogs.controller.launchAs(instanceId, account);
        }
    }
    TextPromptDialog {
        id: profilePromptPopup
        objectName: "profilePrompt"
        anchors.centerIn: Overlay.overlay
        title: "Save mod profile"
        subtitle: "Remembers which mods are on and off. Saving under an existing name replaces it."
        placeholder: "Profile name, e.g. Performance"
        confirmText: "Save"
        Connections {
            target: dialogs.controller.details
            function onErrorOccurred(message) { if (profilePromptPopup.visible) profilePromptPopup.error = message; }
        }
        onSubmitted: value => {
            if (!dialogs.controller.details.saveProfile(value)) return;
            close();
            dialogs.controller.notify("Profile saved");
        }
    }
    DropInstallDialog { id: dropPopup; controller: dialogs.controller; anchors.centerIn: Overlay.overlay }
    GroupNameDialog { id: groupNamePopup; controller: dialogs.controller; anchors.centerIn: Overlay.overlay }
    MoveToGroupDialog { id: moveGroupPopup; controller: dialogs.controller; anchors.centerIn: Overlay.overlay }
    InstanceContextMenu { id: instanceMenuPopup; controller: dialogs.controller }
    CommandPalette { id: commandPalettePopup; controller: dialogs.controller }
    LaunchOverlay { id: launchOverlayPopup; controller: dialogs.controller }
    ArtworkDialog { id: artworkPopup; controller: dialogs.controller; anchors.centerIn: Overlay.overlay }
    ConfirmDialog {
        id: deleteGroupPopup
        property string group: ""
        anchors.centerIn: Overlay.overlay
        title: "Delete “" + group + "”?"
        message: "Its instances move to Ungrouped. No instance or file is deleted."
        confirmText: "Delete group"
        danger: true
        onConfirmed: if (dialogs.controller.instances.deleteGroup(group)) dialogs.controller.afterGroupEdit("Group deleted")
    }
}
