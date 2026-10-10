import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ColumnLayout {
    id: browser
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances
    property bool sidebarVisible: controller.width >= 1200
    function focusSearch() {
        search.forceActiveFocus();
    }
    function focusBrowser() {
        (win.rowsView ? rows : grid).forceActiveFocus();
    }
    function positionSelection(row) {
        grid.positionViewAtIndex(row, GridView.Contain);
        rows.positionViewAtIndex(row, ListView.Contain);
    }

    Layout.fillWidth: true
    Layout.fillHeight: true
    Layout.margins: 24
    Layout.topMargin: 20
    spacing: 12
    LibraryToolbar {
        controller: browser.controller
    }
    InstanceSearch {
        id: search
        controller: browser.controller
        visible: !browser.sidebarVisible
        objectName: browser.sidebarVisible ? "compactSearch" : "searchField"
        onMoveToBrowser: browser.focusBrowser()
    }
    LibraryFilters {
        controller: browser.controller
    }
    Item {
        Layout.fillWidth: true
        Layout.fillHeight: true
        LibraryCoverGrid {
            id: grid
            controller: browser.controller
        }
        LibraryRows {
            id: rows
            controller: browser.controller
        }
        LibraryEmptyState {
            controller: browser.controller
        }
    }
}
