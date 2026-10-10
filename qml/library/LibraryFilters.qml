import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Flow {
    required property var controller
    readonly property var win: controller
    readonly property var instances: controller.instances

    Layout.fillWidth: true
    spacing: 8
    Chip {
        interactive: true
        text: "All " + instances.totalCount
        tint: Colors.accent
        active: win.loaderFilter === ""
        onClicked: {
            win.loaderFilter = "";
            instances.setFilter(win.searchText, "");
        }
    }
    Repeater {
        model: instances.availableLoaders
        delegate: Chip {
            interactive: true
            required property string modelData
            text: modelData + " " + instances.loaderCount(modelData)
            tint: Colors.loaderColor(modelData)
            active: win.loaderFilter === modelData
            onClicked: {
                win.loaderFilter = modelData;
                instances.setFilter(win.searchText, modelData);
            }
        }
    }
}
