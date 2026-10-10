import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Duplicate, missing-dependency, incompatibility and wrong-loader findings for the
// open instance, each with one-click fixes. Severity is always spelled out, not only coloured.
Rectangle {
    id: panel
    required property var controller
    readonly property var health: controller.modHealth
    readonly property var contents: controller.details
    readonly property bool current: !!health && health.instanceId === contents.instanceId
    readonly property var issues: current ? health.issues : []
    property bool expanded: true
    property bool showAll: false
    // Short windows keep room for the mod list itself.
    readonly property int previewCount: controller.height >= 800 ? 3 : 1
    function apply(fix) {
        if (fix.action === "browse") {
            controller.browseFor(contents.instanceId, fix.value);
            return;
        }
        const count = contents.setModsEnabled(fix.value, fix.action === "enable");
        if (count) controller.notify((fix.action === "enable" ? "Enabled " : "Disabled ") + count + (count === 1 ? " mod" : " mods"));
    }
    visible: current && (health.checking || issues.length > 0)
    Layout.fillWidth: true
    implicitHeight: body.implicitHeight + 24
    radius: 12
    readonly property color tone: !current || health.errors > 0 ? Colors.danger : Colors.warning
    color: Qt.rgba(tone.r, tone.g, tone.b, 0.07)
    border.color: Qt.rgba(tone.r, tone.g, tone.b, 0.35)
    ColumnLayout {
        id: body
        anchors { fill: parent; margins: 12; leftMargin: 16; rightMargin: 12 }
        spacing: 8
        RowLayout {
            Layout.fillWidth: true
            spacing: 10
            BusyIndicator {
                visible: panel.current && panel.health.checking
                running: visible
                implicitWidth: 20
                implicitHeight: 20
            }
            Text {
                visible: !(panel.current && panel.health.checking)
                text: "!"
                color: panel.tone
                font.pixelSize: 16
                font.weight: Font.Black
            }
            Text {
                Layout.fillWidth: true
                text: !panel.current ? "" : panel.health.checking ? "Checking mods for conflicts…"
                    : (panel.health.errors ? panel.health.errors + (panel.health.errors === 1 ? " error" : " errors") : "")
                      + (panel.health.errors && panel.health.warnings ? " · " : "")
                      + (panel.health.warnings ? panel.health.warnings + (panel.health.warnings === 1 ? " warning" : " warnings") : "")
                      + (panel.health.errors ? " — the game will likely fail to start" : "")
                color: Colors.text
                font.pixelSize: 13
                font.weight: Font.DemiBold
                elide: Text.ElideRight
            }
            TextLink {
                text: "Check again"
                pixelSize: 12
                enabled: panel.current && !panel.health.checking
                onClicked: panel.health.recheck()
            }
            TextLink {
                visible: panel.issues.length > 0
                text: panel.expanded ? "Hide" : "Show"
                pixelSize: 12
                onClicked: panel.expanded = !panel.expanded
            }
        }
        Repeater {
            model: !panel.expanded ? [] : panel.showAll ? panel.issues : panel.issues.slice(0, panel.previewCount)
            delegate: Rectangle {
                id: issue
                required property var modelData
                Layout.fillWidth: true
                implicitHeight: row.implicitHeight + 16
                radius: 8
                color: Colors.surface
                border.color: Colors.border
                RowLayout {
                    id: row
                    anchors { fill: parent; margins: 8; leftMargin: 12 }
                    spacing: 12
                    Rectangle {
                        implicitWidth: label.implicitWidth + 14
                        implicitHeight: 20
                        radius: 6
                        readonly property color tone: issue.modelData.severity === "error" ? Colors.danger : Colors.warning
                        color: Qt.rgba(tone.r, tone.g, tone.b, 0.15)
                        Text {
                            id: label
                            anchors.centerIn: parent
                            text: issue.modelData.severity === "error" ? "ERROR" : "WARNING"
                            color: parent.tone
                            font.pixelSize: 10
                            font.weight: Font.Bold
                            font.letterSpacing: 1
                        }
                    }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 2
                        Layout.minimumWidth: 160
                        Text { Layout.fillWidth: true; text: issue.modelData.title; color: Colors.text; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: issue.modelData.detail; color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                    }
                    Repeater {
                        model: issue.modelData.fixes
                        delegate: ActionButton {
                            required property var modelData
                            required property int index
                            text: modelData.label
                            implicitHeight: 32
                            implicitWidth: Math.min(220, contentItem.implicitWidth + 28)
                            Layout.minimumWidth: implicitWidth
                            font.pixelSize: 12
                            primary: index === 0
                            onClicked: panel.apply(modelData)
                        }
                    }
                }
            }
        }
        TextLink {
            visible: panel.expanded && panel.issues.length > panel.previewCount
            text: panel.showAll ? "Show fewer" : "Show all " + panel.issues.length + " problems"
            pixelSize: 12
            onClicked: panel.showAll = !panel.showAll
        }
    }
}
