import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

ColumnLayout {
    id: filesTab
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info
    property string logText: ""
    property string logName: ""
    readonly property string category: ({
            resourcepacks: "resourcepacks",
            shaders: "shaderpacks",
            worlds: "saves",
            logs: "logs"
        })[controller.instanceTab] || ""
    readonly property var allFiles: contents.files.filter(file => file.category === category)
    readonly property var contentFiles: allFiles.filter(file => !fileSearch.text
        || ((file.name || "") + " " + file.fileName).toLowerCase().indexOf(fileSearch.text.trim().toLowerCase()) >= 0)
    onCategoryChanged: fileSearch.text = ""

    anchors {
        fill: parent
        margins: 28
    }
    visible: filesTab.category !== ""
    spacing: 16
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: ({
                    resourcepacks: "Resource packs",
                    shaderpacks: "Shaders",
                    saves: "Worlds",
                    logs: "Logs"
                })[filesTab.category] || ""
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: 28
        }
        Item {
            Layout.fillWidth: true
        }
        InputField {
            id: fileSearch
            objectName: "fileSearch"
            visible: filesTab.allFiles.length > 4
            Layout.preferredWidth: 240
            placeholderText: "Search " + filesTab.allFiles.length + " " + (({ resourcepacks: "packs", shaderpacks: "shaders", saves: "worlds", logs: "logs" })[filesTab.category] || "files") + "…"
            font.pixelSize: 13
        }
        ActionButton {
            objectName: "diagnoseButton"
            visible: filesTab.category === "logs" && !!filesTab.controller.session
            text: "Diagnose last crash"
            implicitWidth: contentItem.implicitWidth + 32
            onClicked: {
                diagnosisDialog.findings = filesTab.controller.session.diagnose(contents.instanceId);
                diagnosisDialog.open();
            }
        }
        ActionButton {
            text: "Open folder"
            onClicked: contents.openContentFolder(filesTab.category)
        }
    }
    ContentUpdates {
        controller: filesTab.controller
        visible: !!controller.updater && (filesTab.category === "resourcepacks" || filesTab.category === "shaderpacks")
        contentType: filesTab.category === "resourcepacks" ? "resourcepack" : "shader"
    }
    DatapackDialog { id: datapackDialog; controller: filesTab.controller; anchors.centerIn: Overlay.overlay }
    MotionDialog {
        id: diagnosisDialog
        property var findings: ({})
        anchors.centerIn: Overlay.overlay
        modal: true
        width: Math.min(filesTab.width - 80, 560)
        padding: 22
        standardButtons: Dialog.Close
        background: Rectangle {
            radius: 14
            color: Colors.surface
            border.color: Colors.border
        }
        contentItem: ScrollView {
            implicitHeight: Math.min(help.implicitHeight + 50, filesTab.height - 160)
            contentWidth: availableWidth
            clip: true
            ColumnLayout {
                width: parent.width
                spacing: 12
                Text {
                    text: "Crash helper"
                    color: Colors.bone
                    font.family: Colors.displayFont
                    font.pixelSize: 20
                }
                CrashHelp {
                    id: help
                    Layout.fillWidth: true
                    controller: filesTab.controller
                    instanceId: filesTab.contents.instanceId
                    diagnosis: diagnosisDialog.findings
                }
            }
        }
    }
    ListView {
        id: contentList
        Layout.fillWidth: true
        Layout.fillHeight: true
        clip: true
        model: filesTab.contentFiles
        spacing: 6
        ScrollBar.vertical: ScrollBar {}
        delegate: ItemDelegate {
            id: fileRow
            required property var modelData
            width: contentList.width
            height: 66
            onClicked: {
                if (filesTab.category === "logs") {
                    filesTab.logName = modelData.fileName;
                    filesTab.logText = contents.readLog(modelData.fileName);
                    logPreview.open();
                } else
                    contents.openFile(modelData.fileName, filesTab.category);
            }
            background: Rectangle {
                radius: 10
                color: fileRow.hovered ? Colors.surfaceHi : Colors.surface
            }
            contentItem: RowLayout {
                spacing: 14
                ContentIcon { source: fileRow.modelData.icon || ""; category: filesTab.category; size: 42 }
                ColumnLayout {
                    Layout.fillWidth: true
                    Text {
                        Layout.fillWidth: true
                        text: fileRow.modelData.fileName
                        color: Colors.text
                        font.pixelSize: 14
                        elide: Text.ElideRight
                    }
                    Text {
                        text: fileRow.modelData.modified + " · " + fileRow.modelData.size
                        color: Colors.subtext
                        font.pixelSize: 12
                    }
                }
                ActionButton {
                    visible: filesTab.category === "saves"
                    text: "Datapacks"
                    onClicked: datapackDialog.openFor(fileRow.modelData.fileName)
                }
                ActionButton {
                    visible: filesTab.category === "saves"
                    text: "Play world"
                    onClicked: if (controller.instances.launchWorld(contents.instanceId, fileRow.modelData.fileName)) controller.followLaunch(contents.instanceId)
                }
            }
        }
        Text {
            anchors.centerIn: parent
            visible: !contents.loading && !filesTab.contentFiles.length
            text: "No " + (({
                        resourcepacks: "resource packs",
                        shaderpacks: "shader packs",
                        saves: "saved worlds",
                        logs: "text logs"
                    })[filesTab.category] || "files") + " found."
            color: Colors.subtext
            font.pixelSize: 15
        }
    }
    MotionDialog {
        id: logPreview
        anchors.centerIn: parent
        width: filesTab.width - 64
        height: filesTab.height - 64
        modal: true
        title: filesTab.logName
        standardButtons: Dialog.Close
        background: Rectangle {
            radius: 14
            color: Colors.surface
            border.color: Colors.border
        }
        contentItem: ScrollView {
            TextArea {
                text: filesTab.logText
                readOnly: true
                textFormat: TextEdit.PlainText
                font.family: "monospace"
                font.pixelSize: 12
                color: Colors.text
                wrapMode: TextEdit.WrapAnywhere
            }
        }
    }
}
