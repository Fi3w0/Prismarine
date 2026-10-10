import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Shapes

// One-time welcome: keep Prismarine, or hand over to Prism's classic window.
Rectangle {
    id: welcome
    required property var controller
    readonly property int instanceCount: controller.instances.allInstances.length
    readonly property int accountCount: controller.instances.accounts.length
    signal finished()

    objectName: "firstRunScreen"
    color: Colors.hero
    clip: true

    function plural(count, word) {
        return count + " " + word + (count === 1 ? "" : "s");
    }
    function useClassic() {
        if (!controller.instances.openPrism())
            return;
        controller.preferences.firstRunSeen = true;
        Qt.quit();
    }

    // Swallow input so nothing underneath reacts while the welcome is shown.
    MouseArea {
        anchors.fill: parent
        acceptedButtons: Qt.AllButtons
        onWheel: wheel => wheel.accepted = true
    }
    Rectangle {
        width: Math.min(welcome.width, welcome.height) * 0.5
        height: width
        anchors.centerIn: parent
        anchors.verticalCenterOffset: -welcome.height * 0.12
        rotation: 45
        color: "transparent"
        border.color: Colors.accent
        opacity: 0.22
        Rectangle {
            anchors.centerIn: parent
            width: parent.width * 0.55
            height: width
            color: "transparent"
            border.color: Colors.accent
        }
    }
    Shape {
        anchors.fill: parent
        layer.enabled: true
        layer.samples: 4
        opacity: 0.25
        ShapePath {
            strokeColor: Colors.accent
            strokeWidth: 1.2
            fillColor: "transparent"
            startX: 0
            startY: welcome.height - 96
            PathCubic {
                control1X: welcome.width * 0.3
                control1Y: welcome.height - 40
                control2X: welcome.width * 0.6
                control2Y: welcome.height - 150
                x: welcome.width
                y: welcome.height - 80
            }
        }
        ShapePath {
            strokeColor: Colors.accent
            strokeWidth: 1.2
            fillColor: "transparent"
            startX: 0
            startY: welcome.height - 60
            PathCubic {
                control1X: welcome.width * 0.3
                control1Y: welcome.height - 4
                control2X: welcome.width * 0.6
                control2Y: welcome.height - 114
                x: welcome.width
                y: welcome.height - 44
            }
        }
    }
    Rectangle {
        anchors.fill: parent
        anchors.margins: 14
        color: "transparent"
        border.color: Colors.heroLine
        visible: Colors.decoFrames
    }

    ColumnLayout {
        anchors.centerIn: parent
        width: Math.min(welcome.width - 80, 760)
        spacing: 0
        Image {
            Layout.alignment: Qt.AlignHCenter
            Layout.preferredWidth: 64
            Layout.preferredHeight: 64
            source: "qrc:/assets/logos/" + welcome.controller.logoFile
            sourceSize.width: 128
            sourceSize.height: 128
            fillMode: Image.PreserveAspectFit
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            Layout.topMargin: 18
            text: "WELCOME TO"
            color: Colors.brass
            font.family: Colors.displayFont
            font.pixelSize: 12
            font.letterSpacing: 4
        }
        Text {
            Layout.alignment: Qt.AlignHCenter
            text: "Prismarine"
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: welcome.height < 720 ? 48 : 60
            font.letterSpacing: 5
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 14
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            textFormat: Text.StyledText
            text: "A new look for Prism Launcher. Everything you already have is here: <b>" + welcome.plural(welcome.instanceCount, "instance") + "</b>, <b>" + welcome.plural(welcome.accountCount, "account") + "</b> and all your settings. Nothing was moved or copied."
            color: Colors.text
            font.pixelSize: 14
            lineHeight: 1.3
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: welcome.height < 720 ? 20 : 30
            spacing: 16
            Repeater {
                model: [
                    { title: "Use Prismarine", detail: "Covers, home page, cleaner mod and settings screens.", action: "Continue", classic: false },
                    { title: "Keep Classic Prism", detail: "Prism Launcher's original window, exactly as before.", action: "Use Classic", classic: true }
                ]
                delegate: Rectangle {
                    id: card
                    required property var modelData
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: cardColumn.implicitHeight + 32
                    radius: 14
                    color: Colors.base
                    border.width: modelData.classic ? 1 : 2
                    border.color: modelData.classic ? Colors.border : Colors.accent
                    ColumnLayout {
                        id: cardColumn
                        anchors {
                            fill: parent
                            margins: 16
                        }
                        spacing: 8
                        Rectangle {
                            Layout.fillWidth: true
                            Layout.preferredHeight: welcome.height < 720 ? 70 : 100
                            radius: 8
                            color: card.modelData.classic ? "#dfe3e7" : Colors.mantle
                            RowLayout {
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                spacing: 6
                                visible: !card.modelData.classic
                                Rectangle {
                                    Layout.preferredWidth: 12
                                    Layout.fillHeight: true
                                    radius: 3
                                    color: Colors.surfaceHi
                                }
                                Repeater {
                                    model: ["#46d1bb", "#b892f2", "#f0a35e", "#7aa2ff"]
                                    delegate: Rectangle {
                                        required property color modelData
                                        Layout.fillWidth: true
                                        Layout.fillHeight: true
                                        radius: 4
                                        color: Qt.darker(modelData, 3.4)
                                    }
                                }
                            }
                            ColumnLayout {
                                anchors {
                                    fill: parent
                                    margins: 8
                                }
                                spacing: 10
                                visible: card.modelData.classic
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
                                        model: 6
                                        delegate: Rectangle {
                                            Layout.fillWidth: true
                                            Layout.preferredHeight: 18
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
                            Layout.topMargin: 6
                            text: card.modelData.title
                            color: Colors.bone
                            font.family: Colors.displayFont
                            font.pixelSize: 20
                            font.letterSpacing: 2
                        }
                        Text {
                            Layout.fillWidth: true
                            text: card.modelData.detail
                            color: Colors.subtext
                            font.pixelSize: 12
                            wrapMode: Text.Wrap
                        }
                        ActionButton {
                            objectName: card.modelData.classic ? "firstRunClassic" : "firstRunContinue"
                            Layout.fillWidth: true
                            Layout.topMargin: 6
                            text: card.modelData.action
                            primary: !card.modelData.classic
                            font.weight: Font.Bold
                            onClicked: card.modelData.classic ? welcome.useClassic() : welcome.finished()
                        }
                    }
                }
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: 22
            horizontalAlignment: Text.AlignHCenter
            wrapMode: Text.Wrap
            text: "Switch any time: Settings → Interface   ·   Classic Prism stays available from About"
            color: Colors.subtext
            font.pixelSize: 11
        }
    }
}
