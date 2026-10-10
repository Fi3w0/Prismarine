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
        font.pixelSize: 14
        font.weight: Font.DemiBold
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 14
        Repeater {
            model: [
                { title: "Prismarine", detail: "The new look. Same instances, accounts and settings.", classic: false },
                { title: "Classic Prism", detail: "Prism Launcher's original window. Switch back any time from its menu.", classic: true }
            ]
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
                    radius: 12
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
                                    model: 5
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
                    Text {
                        Layout.topMargin: 4
                        text: option.modelData.title + (option.current ? "  ·  in use" : "  ↗")
                        color: Colors.text
                        font.pixelSize: 13
                        font.weight: Font.DemiBold
                    }
                    Text {
                        Layout.fillWidth: true
                        text: option.modelData.detail
                        color: Colors.subtext
                        font.pixelSize: 11
                        wrapMode: Text.Wrap
                    }
                }
            }
        }
    }
}
