import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: library
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances
    function focusSearch() {
        (sidebar.visible ? sidebar : browser).focusSearch();
    }
    function clearSearch() {
        win.searchText = "";
    }
    function positionSelection(row) {
        browser.positionSelection(row);
    }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        LibrarySidebar {
            id: sidebar
            controller: library.controller
            onFocusBrowser: browser.focusBrowser()
        }
        Item {
            visible: sidebar.visible
            Layout.preferredWidth: 7
            Layout.fillHeight: true
            Rectangle {
                anchors.centerIn: parent
                width: resizeHandle.containsMouse || resizeHandle.pressed ? 3 : 1
                height: parent.height
                color: resizeHandle.containsMouse || resizeHandle.pressed ? Colors.accent : Colors.border
                Behavior on color { ColorAnimation { duration: Colors.animations ? 180 : 0 } }
            }
            MouseArea {
                id: resizeHandle
                objectName: "libraryResizeHandle"
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.SplitHCursor
                property real startX
                property int startWidth
                onPressed: mouse => { startX = mapToItem(library, mouse.x, 0).x; startWidth = library.controller.preferences.sidebarWidth; }
                onPositionChanged: mouse => {
                    if (pressed) library.controller.preferences.sidebarWidth = Math.min(library.width - 680, startWidth + mapToItem(library, mouse.x, 0).x - startX);
                }
                onDoubleClicked: library.controller.preferences.sidebarWidth = 248
                Accessible.name: "Resize instance sidebar"
            }
        }
        LibraryBrowser {
            id: browser
            controller: library.controller
        }
        LibraryDetails {
            controller: library.controller
        }
    }
}
