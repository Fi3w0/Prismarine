import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

GridLayout {
    required property var controller
    required property string section

    visible: section === "Library & covers"
    Layout.fillWidth: true
    columns: width < 620 ? 1 : 2
    columnSpacing: 24
    rowSpacing: 24
    ColumnLayout {
        Layout.fillWidth: true
        Text {
            text: "Library view"
            color: Colors.text
            font.pixelSize: Typography.control
            font.weight: Font.DemiBold
        }
        Text {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            text: "How your instances are shown."
            color: Colors.subtext
            font.pixelSize: Typography.bodySmall
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
        Text { text: qsTr("Library density"); color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold }
        Text { Layout.fillWidth: true; text: qsTr("Smaller covers and shorter rows, with the same readable text."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
        SelectBox {
            objectName: "libraryDensityPicker"
            Layout.fillWidth: true
            model: [qsTr("Comfortable"), qsTr("Compact")]
            currentIndex: controller.preferences.libraryDensity === "compact" ? 1 : 0
            onActivated: controller.preferences.libraryDensity = currentIndex ? "compact" : "comfortable"
        }
    }
    Text {
        Layout.fillWidth: true
        Layout.columnSpan: parent.columns
        text: qsTr("To change an instance's card or banner image, open its Cover action in the Library.")
        color: Colors.subtext
        font.pixelSize: Typography.bodySmall
        wrapMode: Text.Wrap
    }
    ColumnLayout {
        Layout.fillWidth: true
        Text { text: qsTr("Cover size"); color: Colors.text; font.pixelSize: Typography.control; font.weight: Font.DemiBold }
        SelectBox {
            objectName: "coverSizePicker"
            Layout.fillWidth: true
            readonly property var sizes: [0, 170, 220, 280]
            model: [qsTr("Follow density"), qsTr("Small"), qsTr("Medium"), qsTr("Large")]
            currentIndex: sizes.indexOf(controller.preferences.coverSize)
            onActivated: controller.preferences.coverSize = sizes[currentIndex]
        }
    }
    ToggleSwitch {
        Layout.fillWidth: true
        objectName: "showCoverBadgesToggle"
        text: qsTr("Loader badges on covers")
        checked: controller.preferences.showCoverBadges
        onToggled: controller.preferences.showCoverBadges = checked
    }

}
