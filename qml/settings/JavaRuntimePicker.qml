import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: picker
    required property var manager
    property string javaPath: ""
    property string arguments: ""
    property int minMemory: 512
    property int maxMemory: 4096
    signal selected(string path)
    spacing: 8
    RowLayout {
        Layout.fillWidth: true
        SelectBox {
            id: runtimes
            Layout.fillWidth: true
            model: picker.manager ? picker.manager.runtimes : []
            textRole: "label"
            enabled: !!picker.manager && !picker.manager.busy && model.length > 0
            onActivated: picker.selected(model[currentIndex].path)
        }
        ActionButton { text: "Find Java"; enabled: !!picker.manager && !picker.manager.busy; onClicked: picker.manager.discover() }
        ActionButton { text: "Test"; enabled: !!picker.manager && !picker.manager.busy && !!picker.javaPath; onClicked: picker.manager.test(picker.javaPath, picker.arguments, picker.minMemory, picker.maxMemory) }
    }
    Text { Layout.fillWidth: true; visible: runtimes.currentIndex >= 0; text: (runtimes.model[runtimes.currentIndex] || {}).path || ""; color: Colors.subtext; font.pixelSize: 11; elide: Text.ElideMiddle }
    RowLayout {
        Text { text: "Download Temurin"; color: Colors.subtext; font.pixelSize: 13 }
        SelectBox { id: major; model: ["8", "17", "21", "25"]; currentIndex: 2; enabled: !!picker.manager && !picker.manager.busy }
        ActionButton { text: "Download"; enabled: !!picker.manager && !picker.manager.busy; onClicked: picker.manager.download(Number(major.currentText)) }
    }
    ProgressBar { Layout.fillWidth: true; visible: !!picker.manager && picker.manager.busy; value: picker.manager ? picker.manager.progress : 0; indeterminate: value === 0 }
    Text { Layout.fillWidth: true; text: picker.manager ? picker.manager.message : ""; visible: !!text; color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.Wrap }
    Text { Layout.fillWidth: true; text: "Downloads stay in Prism's data folder. Select a runtime above, then save settings to use it."; color: Colors.subtext; font.pixelSize: 11; wrapMode: Text.Wrap }
}
