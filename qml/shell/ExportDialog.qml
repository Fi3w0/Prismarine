import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// Share an instance as a small Modrinth pack or keep a complete Prism backup.
MotionDialog {
    id: dialog
    required property var controller
    readonly property var exporter: controller.packExporter
    property string instanceId: ""
    property string format: "mrpack"
    readonly property var info: controller.instances.getById(instanceId)
    readonly property bool busy: !!exporter && (exporter.state === "preparing" || exporter.state === "exporting")
    function openFor(id) {
        instanceId = id;
        format = "mrpack";
        configs.checked = true;
        resources.checked = true;
        servers.checked = true;
        options.checked = false;
        worlds.checked = false;
        disabled.checked = false;
        version.text = "1.0.0";
        description.text = "";
        open();
    }
    modal: true
    width: Math.min(620, controller.width - 80)
    padding: 24
    background: Rectangle {
        radius: 14
        color: Colors.surface
        border.color: Colors.border
    }
    onClosed: if (exporter && exporter.state !== "exporting" && exporter.state !== "preparing")
        exporter.cancel()
    contentItem: ColumnLayout {
        spacing: 14
        Text {
            text: "Export " + (dialog.info.name || "instance")
            color: Colors.bone
            font.family: Colors.displayFont
            font.pixelSize: 24
            font.letterSpacing: 1
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 12
            Repeater {
                model: [
                    { key: "mrpack", title: "Share with friends", detail: ".mrpack · small. Mods from Modrinth download on import; everything else is packed in. Opens in Prismarine, Prism, Modrinth App and others." },
                    { key: "zip", title: "Full backup", detail: ".zip · the whole instance as a Prism/MultiMC export. Larger, works offline." }
                ]
                delegate: AbstractButton {
                    id: choice
                    required property var modelData
                    readonly property bool current: dialog.format === modelData.key
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 104
                    padding: 14
                    hoverEnabled: true
                    Accessible.name: modelData.title
                    onClicked: dialog.format = modelData.key
                    background: Rectangle {
                        radius: 12
                        color: choice.current ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.1) : Colors.mantle
                        border.width: choice.current ? 2 : 1
                        border.color: choice.current || choice.visualFocus ? Colors.accent : Colors.border
                    }
                    contentItem: ColumnLayout {
                        spacing: 4
                        Text {
                            text: choice.modelData.title
                            color: Colors.text
                            font.pixelSize: 14
                            font.weight: Font.DemiBold
                        }
                        Text {
                            Layout.fillWidth: true
                            Layout.fillHeight: true
                            text: choice.modelData.detail
                            color: Colors.subtext
                            font.pixelSize: 11
                            wrapMode: Text.Wrap
                        }
                    }
                }
            }
        }
        Text {
            text: "Include"
            color: Colors.subtext
            font.pixelSize: 12
        }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 18
            rowSpacing: 6
            component Option: RowLayout {
                property alias checked: box.checked
                property string label: ""
                property string hint: ""
                spacing: 8
                TickBox {
                    id: box
                    Accessible.name: parent.label
                }
                ColumnLayout {
                    spacing: 0
                    TapHandler { onTapped: box.toggle() }
                    Text { text: label; color: Colors.text; font.pixelSize: 12 }
                    Text { text: hint; color: Colors.subtext; font.pixelSize: 10 }
                }
            }
            Option { id: configs; label: "Mod configs"; hint: "config, defaultconfigs, kubejs" }
            Option { id: resources; label: "Resource packs & shaders"; hint: "Modrinth ones download" }
            Option { id: servers; label: "Server list"; hint: "So friends can join right away" }
            Option { id: options; label: "Game options"; hint: "Keybinds, video settings" }
            Option { id: worlds; label: "Worlds"; hint: "Can be very large" }
            Option { id: disabled; label: "Disabled mods"; hint: "Files ending in .disabled" }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: dialog.format === "mrpack"
            spacing: 10
            InputField {
                id: version
                Layout.preferredWidth: 110
                implicitHeight: 34
                font.pixelSize: 12
                placeholderText: "Version"
            }
            InputField {
                id: description
                Layout.fillWidth: true
                implicitHeight: 34
                font.pixelSize: 12
                placeholderText: "Short description for friends (optional)"
            }
        }
        Text {
            Layout.fillWidth: true
            visible: !!dialog.exporter && dialog.exporter.state !== "idle"
            text: !dialog.exporter ? "" : dialog.exporter.state === "preparing" ? "Checking which mods Modrinth hosts…"
                : dialog.exporter.state === "exporting" ? "Packing… " + Math.round(dialog.exporter.progress * 100) + "%"
                : dialog.exporter.state === "complete" ? "Saved " + dialog.exporter.output.split("/").pop() + " · " + dialog.exporter.summary.downloads + " downloads, "
                    + dialog.exporter.summary.files + " files packed, " + (dialog.exporter.summary.bytes / 1048576).toFixed(1) + " MiB"
                : dialog.exporter.error
            color: dialog.exporter && dialog.exporter.state === "error" ? Colors.danger : dialog.exporter && dialog.exporter.state === "complete" ? Colors.success : Colors.subtext
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 4
            TextLink {
                visible: !!dialog.exporter && dialog.exporter.state === "complete"
                text: "Show in folder ↗"
                onClicked: Qt.openUrlExternally("file:///" + dialog.exporter.output.substring(0, dialog.exporter.output.lastIndexOf("/")).replace(/^\/+/, ""))
            }
            Item {
                Layout.fillWidth: true
            }
            ActionButton {
                text: dialog.exporter && dialog.exporter.state === "complete" ? "Done" : "Cancel"
                implicitWidth: 100
                onClicked: dialog.close()
            }
            ActionButton {
                objectName: "exportPackButton"
                text: dialog.busy ? "Exporting…" : "Export…"
                primary: true
                implicitWidth: 120
                enabled: !dialog.busy && !!dialog.exporter
                onClicked: saveDialog.open()
            }
        }
    }
    FileDialog {
        id: saveDialog
        fileMode: FileDialog.SaveFile
        title: dialog.format === "zip" ? "Save instance backup" : "Save modpack"
        currentFile: "file:///" + (dialog.info.name || "pack").replace(/[^A-Za-z0-9 _.-]+/g, "-") + "." + dialog.format
        nameFilters: dialog.format === "zip" ? ["Prism instance (*.zip)"] : ["Modrinth modpack (*.mrpack)"]
        onAccepted: dialog.exporter.exportPack(dialog.instanceId, selectedFile, dialog.format, {
            configs: configs.checked,
            resources: resources.checked,
            servers: servers.checked,
            options: options.checked,
            worlds: worlds.checked,
            disabled: disabled.checked,
            version: version.text || "1.0.0",
            description: description.text
        })
    }
}
