import QtQuick

// The main window's keyboard shortcuts. DOCUMENTATION.md lists them for users.
Item {
    id: shortcuts
    required property var controller

    Shortcut {
        sequence: "F11"
        onActivated: shortcuts.controller.visibility = shortcuts.controller.visibility === Window.FullScreen ? Window.Windowed : Window.FullScreen
    }
    Shortcut {
        sequences: ["Ctrl+K", "Ctrl+Shift+P"]
        onActivated: shortcuts.controller.openPalette()
    }
    Shortcut {
        sequence: "Ctrl+F"
        onActivated: {
            shortcuts.controller.navigate("library");
            if (shortcuts.controller.pageItem)
                shortcuts.controller.pageItem.focusSearch();
        }
    }
    Shortcut {
        sequence: "F2"
        enabled: !shortcuts.controller.dialogs.rename.visible && ((shortcuts.controller.page === "library" && shortcuts.controller.hasSelection) || (shortcuts.controller.page === "instance" && !!shortcuts.controller.details.instanceId))
        onActivated: shortcuts.controller.renameInstance(shortcuts.controller.page === "instance" ? shortcuts.controller.details.instanceId : shortcuts.controller.current.instanceId)
    }
    Shortcut {
        sequence: "Ctrl+R"
        onActivated: shortcuts.controller.reloadLibrary()
    }
    Shortcut {
        sequence: "F5"
        onActivated: shortcuts.controller.reloadLibrary()
    }
    Shortcut {
        sequence: "Alt+Left"
        onActivated: shortcuts.controller.back()
    }
}
