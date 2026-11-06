import QtQuick

// Marks something that needs Full mode.
Rectangle {
    id: badge
    property string text: qsTr("Full mode only")
    implicitWidth: label.implicitWidth + 18
    implicitHeight: label.implicitHeight + 6
    radius: height / 2
    color: Qt.rgba(Colors.brass.r, Colors.brass.g, Colors.brass.b, 0.14)
    border.color: Colors.brass
    Accessible.role: Accessible.StaticText
    Accessible.name: text
    Text {
        id: label
        anchors.centerIn: parent
        text: badge.text
        color: Colors.brass
        font.pixelSize: Typography.caption
        font.weight: Font.DemiBold
    }
}
