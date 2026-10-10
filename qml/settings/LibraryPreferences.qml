import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

RowLayout {
    required property var controller
    required property string section

    visible: section === "Interface" || section === "Library & covers" || section === "Java & game"
    Layout.fillWidth: true
    spacing: 32
    ColumnLayout {
        Layout.fillWidth: true
        Text {
            text: "Library view"
            color: Colors.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            text: "How your instances are shown."
            color: Colors.subtext
            font.pixelSize: 12
        }
        SelectBox {
            Layout.fillWidth: true
            model: ["Covers", "List"]
            currentIndex: controller.preferences.libraryView === "covers" ? 0 : 1
            onActivated: controller.preferences.libraryView = currentIndex === 0 ? "covers" : "rows"
        }
    }
    ColumnLayout {
        Layout.fillWidth: true
        Text {
            text: "Start page"
            color: Colors.text
            font.pixelSize: 14
            font.weight: Font.DemiBold
        }
        Text {
            text: "What opens when you launch Prismarine."
            color: Colors.subtext
            font.pixelSize: 12
        }
        SelectBox {
            Layout.fillWidth: true
            model: ["Home", "Library"]
            currentIndex: controller.preferences.startPage === "home" ? 0 : 1
            onActivated: controller.preferences.startPage = currentIndex === 0 ? "home" : "library"
        }
    }
}
