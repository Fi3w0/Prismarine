import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

MotionDialog {
    id: dialog
    required property var controller
    readonly property var importer: controller.packImporter
    readonly property bool busy: importer.state === "extracting" || importer.state === "downloading" || importer.state === "fetching"
    readonly property bool done: importer.state === "complete" || importer.state === "handedoff"
    title: "Import modpack"
    subtitle: "Modrinth .mrpack and Prism/MultiMC exports import here. CurseForge, ATLauncher, Technic and FTB zips open in Prism's importer, which knows their download services."
    width: Math.min(620, controller.width - 64)
    modal: true
    onClosed: if (!done)
        importer.cancel()
    contentItem: ColumnLayout {
        spacing: 14
        // Drop zone: the whole box is also a button that opens the file picker.
        AbstractButton {
            id: zone
            Layout.fillWidth: true
            implicitHeight: 168
            enabled: !dialog.busy
            hoverEnabled: true
            Accessible.name: "Choose pack file"
            onClicked: filePicker.open()
            background: Rectangle {
                radius: 14
                color: drop.containsDrag ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.14) : zone.hovered ? Colors.surfaceHi : Colors.inset
                border.width: drop.containsDrag || zone.visualFocus ? 2 : 1
                border.color: drop.containsDrag || zone.visualFocus ? Colors.accent : Colors.border
                Behavior on color { ColorAnimation { duration: Colors.animations ? 140 : 0 } }
            }
            contentItem: ColumnLayout {
                spacing: 10
                Item { Layout.fillHeight: true }
                Rectangle {
                    Layout.alignment: Qt.AlignHCenter
                    implicitWidth: 48
                    implicitHeight: 48
                    radius: 24
                    color: Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.14)
                    BusyIndicator {
                        anchors.centerIn: parent
                        running: dialog.busy
                        visible: running
                        implicitWidth: 32
                        implicitHeight: 32
                    }
                    LineIcon {
                        anchors.centerIn: parent
                        visible: !dialog.busy
                        name: dialog.done ? "play" : "plus"
                        tint: Colors.accent
                    }
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: dialog.busy ? (dialog.importer.state === "extracting" ? "Unpacking…" : "Downloading pack files…")
                        : dialog.importer.state === "complete" ? "Pack imported"
                        : dialog.importer.state === "handedoff" ? "Opened in Prism's importer"
                        : "Drop a pack here or click to choose"
                    color: Colors.text
                    font.pixelSize: 15
                    font.weight: Font.DemiBold
                }
                Text {
                    Layout.alignment: Qt.AlignHCenter
                    text: dialog.importer.state === "handedoff" ? "It appears in your library when Prism finishes." : ".mrpack or .zip"
                    color: Colors.subtext
                    font.pixelSize: 12
                }
                Item { Layout.fillHeight: true }
            }
            DropArea {
                id: drop
                anchors.fill: parent
                keys: ["text/uri-list"]
                enabled: !dialog.busy
                onEntered: drag => { if (!drag.hasUrls) drag.accepted = false; }
                onDropped: drop => {
                    if (!drop.hasUrls) return;
                    drop.acceptProposedAction();
                    dialog.importer.importFile(drop.urls[0]);
                }
            }
        }
        ProgressBar {
            id: progress
            Layout.fillWidth: true
            visible: dialog.importer.state === "downloading" || dialog.importer.state === "fetching"
            from: 0
            to: 1
            value: dialog.importer.progress
            background: Rectangle { implicitHeight: 6; radius: 3; color: Colors.inset }
            contentItem: Item {
                Rectangle { width: progress.visualPosition * parent.width; height: parent.height; radius: 3; color: Colors.accent }
            }
        }
        Text {
            Layout.fillWidth: true
            text: dialog.importer.error
            visible: !!text
            color: Colors.danger
            wrapMode: Text.Wrap
        }
        Text {
            Layout.fillWidth: true
            text: "Downloads are verified before the new instance is added to your library."
            color: Colors.subtext
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
    }
    footer: DialogActions {
        cancelText: dialog.done ? "Close" : "Cancel"
        confirmText: "Choose file…"
        confirmVisible: !dialog.done
        confirmEnabled: !dialog.busy
        onCancelled: dialog.close()
        onConfirmed: filePicker.open()
    }
    FileDialog {
        id: filePicker
        title: "Choose a modpack"
        nameFilters: ["Modpacks (*.mrpack *.zip)"]
        onAccepted: dialog.importer.importFile(selectedFile)
    }
}
