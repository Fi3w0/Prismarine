import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Plain-language crash findings, each with the step most likely to fix it.
ColumnLayout {
    id: help
    required property var controller
    required property string instanceId
    required property var diagnosis
    readonly property var findings: diagnosis && diagnosis.findings ? diagnosis.findings : []
    spacing: 8
    Text {
        Layout.fillWidth: true
        visible: !help.findings.length
        text: help.diagnosis && help.diagnosis.crashed === false ? "No crash found in the latest log." : "No common cause was found. Share the log to ask for help."
        color: Colors.subtext
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }
    Repeater {
        model: help.findings
        delegate: Rectangle {
            id: item
            required property var modelData
            Layout.fillWidth: true
            implicitHeight: body.implicitHeight + 22
            radius: 10
            color: Qt.rgba(Colors.warning.r, Colors.warning.g, Colors.warning.b, 0.08)
            border.color: Qt.rgba(Colors.warning.r, Colors.warning.g, Colors.warning.b, 0.35)
            ColumnLayout {
                id: body
                anchors {
                    left: parent.left
                    right: parent.right
                    top: parent.top
                    margins: 11
                }
                spacing: 4
                Text {
                    Layout.fillWidth: true
                    text: item.modelData.title
                    color: Colors.text
                    font.pixelSize: 13
                    font.weight: Font.DemiBold
                    wrapMode: Text.Wrap
                }
                Text {
                    Layout.fillWidth: true
                    text: item.modelData.detail
                    color: Colors.subtext
                    font.pixelSize: 11
                    wrapMode: Text.Wrap
                    maximumLineCount: 6
                    elide: Text.ElideRight
                }
                TextLink {
                    visible: item.modelData.action !== ""
                    Layout.topMargin: 2
                    text: item.modelData.action === "browse" ? "Find " + item.modelData.query + " on Modrinth →"
                        : item.modelData.action === "settings" ? "Open instance settings →" : "Open the Mods tab →"
                    onClicked: {
                        const a = item.modelData.action;
                        if (a === "browse")
                            help.controller.browseFor(help.instanceId, item.modelData.query);
                        else if (a === "settings")
                            help.controller.editSettings(help.instanceId);
                        else
                            help.controller.openInstance(help.instanceId, "mods");
                    }
                }
            }
        }
    }
    TextLink {
        visible: !!help.diagnosis && !!help.diagnosis.report
        text: "Open the crash report ↗"
        tint: Colors.subtext
        underline: false
        onClicked: help.controller.session.openReport(help.diagnosis.report)
    }
}
