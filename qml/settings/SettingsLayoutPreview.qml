import QtQuick
import QtQuick.Layouts

Rectangle {
    id: preview
    required property var preferences
    Layout.fillWidth: true
    implicitHeight: content.implicitHeight + 40
    radius: 20
    color: Colors.surface
    border.color: Colors.border
    ColorPalette { id: sample; systemMode: Colors.systemMode; theme: preview.preferences.theme; userAccent: preview.preferences.accentColor; cornerStyle: preview.preferences.cornerStyle; overrides: preview.preferences.paletteOverrides }
    ColumnLayout {
        id: content
        anchors { left: parent.left; right: parent.right; top: parent.top; margins: 20 }
        spacing: 16
        Text { text: qsTr("Library preview"); color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: Typography.body; font.letterSpacing: 2 }
        Rectangle {
            Layout.fillWidth: true
            implicitHeight: mock.implicitHeight + 28
            radius: sample.controlRadius
            color: sample.base
            GridLayout {
                id: mock
                anchors { left: parent.left; right: parent.right; top: parent.top; margins: 14 }
                columns: preview.preferences.libraryView === "rows" ? 1 : Math.min(width < 500 ? 3 : 5, preview.preferences.coverSize === 280 ? 2 : preview.preferences.coverSize === 170 || preview.preferences.libraryDensity === "compact" ? 4 : 3)
                columnSpacing: 12
                rowSpacing: preview.preferences.libraryDensity === "compact" ? 6 : 12
                Repeater {
                    model: [qsTr("Coastal survival"), qsTr("Building together"), qsTr("Ocean discoveries")]
                    delegate: Rectangle {
                        id: cover
                        required property string modelData
                        required property int index
                        readonly property bool rows: preview.preferences.libraryView === "rows"
                        Layout.fillWidth: true
                        Layout.preferredWidth: 1
                        implicitHeight: rows ? (preview.preferences.libraryDensity === "compact" ? 44 : 62) : 124
                        radius: sample.controlRadius
                        color: rows ? sample.surface : Qt.darker(["#46d1bb", "#b892f2", "#f0a35e"][index], 3.4)
                        border.color: preview.preferences.decoFrames ? Colors.brass : sample.border
                        Text {
                            anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                            text: cover.modelData
                            color: cover.rows ? sample.text : Colors.artText
                            font.pixelSize: Typography.bodySmall
                            elide: Text.ElideRight
                        }
                        Text {
                            visible: !cover.rows && preview.preferences.showCoverBadges
                            anchors { top: parent.top; left: parent.left; margins: 12 }
                            text: ["Fabric", "Forge", "Quilt"][cover.index]
                            color: Colors.artSubtext
                            font.pixelSize: Typography.caption
                        }
                    }
                }
            }
        }
        Text { Layout.fillWidth: true; text: qsTr("Cover size, density, badges and frame changes stay in this preview until Apply."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
    }
}
