import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// "Launcher UI" chooser: Prismarine is the current window; Classic opens Prism itself.
ColumnLayout {
    id: chooser
    required property var controller
    required property string section

    Layout.fillWidth: true
    visible: section === "Interface"
    spacing: 10
    Text {
        text: "Launcher UI"
        color: Colors.text
        font.pixelSize: Typography.control
        font.weight: Font.DemiBold
    }
    GridLayout {
        Layout.fillWidth: true
        columns: width < 600 ? 1 : 2
        columnSpacing: 16
        rowSpacing: 16
        Repeater {
            model: [
                { title: "Prismarine", detail: "The new look. Same instances, accounts and settings.", classic: false },
                { title: "Classic Prism", detail: "Opens Prism Launcher's original window. Prismarine stays installed.", classic: true }
            ].filter(option => !option.classic || chooser.controller.prismShortcuts !== false)
            delegate: AbstractButton {
                id: option
                required property var modelData
                readonly property bool current: !modelData.classic
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 196
                padding: 14
                hoverEnabled: true
                Accessible.name: modelData.title
                onClicked: if (modelData.classic && chooser.controller.instances.openPrism()) chooser.controller.notify("Opening Classic Prism…")
                background: Rectangle {
                    radius: 20
                    color: option.current ? Colors.surfaceHi : Colors.surface
                    border.width: option.current ? 2 : 1
                    border.color: option.current || option.visualFocus ? Colors.accent : option.hovered ? Colors.subtext : Colors.border
                    Behavior on border.color { ColorAnimation { duration: Colors.animations ? 160 : 0 } }
                }
                contentItem: ColumnLayout {
                    spacing: 6
                    Rectangle {
                        Layout.fillWidth: true
                        Layout.preferredHeight: 92
                        radius: 6
                        color: option.modelData.classic ? "#e3e6ea" : Colors.base
                        RowLayout {
                            anchors {
                                fill: parent
                                margins: 8
                            }
                            spacing: 6
                            visible: !option.modelData.classic
                            Rectangle {
                                Layout.preferredWidth: 10
                                Layout.fillHeight: true
                                radius: 3
                                color: Colors.mantle
                            }
                            Repeater {
                                model: ["#46d1bb", "#b892f2", "#f0a35e", "#7aa2ff"]
                                delegate: Rectangle {
                                    required property color modelData
                                    Layout.fillWidth: true
                                    Layout.fillHeight: true
                                    radius: 3
                                    color: Qt.darker(modelData, 3.4)
                                    border.color: Qt.rgba(Colors.brass.r, Colors.brass.g, Colors.brass.b, 0.3)
                                }
                            }
                        }
                        ColumnLayout {
                            anchors {
                                fill: parent
                                margins: 8
                            }
                            spacing: 8
                            visible: option.modelData.classic
                            Rectangle {
                                Layout.fillWidth: true
                                Layout.preferredHeight: 8
                                radius: 2
                                color: "#c3c8ce"
                            }
                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 6
                                Repeater {
                                    model: 3
                                    delegate: Rectangle {
                                        Layout.fillWidth: true
                                        Layout.preferredHeight: 16
                                        radius: 2
                                        color: "#9aa3ad"
                                    }
                                }
                            }
                            Item {
                                Layout.fillHeight: true
                            }
                        }
                    }
                    RowLayout {
                        Layout.fillWidth: true
                        Layout.topMargin: 4
                        spacing: 8
                        Text { text: option.modelData.title + (option.current ? "" : "  ↗"); color: Colors.text; font.pixelSize: Typography.body; font.weight: Font.DemiBold }
                        Rectangle {
                            visible: option.current
                            implicitWidth: 54; implicitHeight: 22; radius: 11; color: Colors.accent
                            Text { anchors.centerIn: parent; text: qsTr("In use"); color: Colors.accentInk; font.pixelSize: Typography.caption; font.weight: Font.DemiBold }
                        }
                        Item { Layout.fillWidth: true }
                    }
                    Text {
                        Layout.fillWidth: true
                        text: option.modelData.detail
                        color: Colors.subtext
                        font.pixelSize: Typography.caption
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
