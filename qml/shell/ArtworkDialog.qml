import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs
import QtCore

MotionDialog {
    id: dialog
    objectName: "artworkDialog"
    required property var controller
    property string instanceId: ""
    property string target: "both"
    property var shots: []
    readonly property var info: controller.instances.getById(instanceId)
    readonly property var modes: [
        { mode: "", label: qsTr("Use settings"), hint: qsTr("Follow your screenshot preference") },
        { mode: "art", label: qsTr("Water cover"), hint: qsTr("Generated for this instance") },
        { mode: "screenshot", label: qsTr("Latest screenshot"), hint: qsTr("Update when you take a new one") }
    ]
    function openFor(id) {
        instanceId = id;
        target = "both";
        shots = controller.instances.screenshots(id, 24);
        open();
    }
    function apply(mode, url) {
        if (controller.preferences.setArtwork(instanceId, target, mode, url || ""))
            controller.notify(target === "both" ? qsTr("Card and banner updated") : target === "card" ? qsTr("Card updated") : qsTr("Banner updated"));
    }
    function modeOf(slot) { return controller.artworkOf(instanceId, slot).mode; }
    readonly property string activeMode: target === "both" ? (modeOf("card") === modeOf("hero") ? modeOf("card") : "mixed") : modeOf(target)
    title: qsTr("Instance artwork")
    subtitle: info.name || ""
    width: Math.min(800, controller.width - 64)
    height: Math.min(implicitHeight, controller.height - 64)
    modal: true

    component SlotPreview: AbstractButton {
        id: preview
        property string slot: "card"
        property string label: ""
        readonly property bool chosen: dialog.target === slot
        hoverEnabled: true
        Accessible.name: qsTr("Edit %1 image").arg(label.toLowerCase())
        onClicked: dialog.target = dialog.target === slot ? "both" : slot
        contentItem: ColumnLayout {
            spacing: 10
            RowLayout {
                Layout.fillWidth: true
                Text { text: preview.label; color: Colors.text; font.pixelSize: Typography.body; font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true
                    text: ({ "": qsTr("Use settings"), art: qsTr("Water cover"), screenshot: qsTr("Latest screenshot"), image: qsTr("Custom image") })[dialog.modeOf(preview.slot)] || ""
                    color: Colors.subtext
                    font.pixelSize: Typography.caption
                    horizontalAlignment: Text.AlignRight
                    elide: Text.ElideRight
                }
            }
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Loader {
                    id: picture
                    anchors.centerIn: parent
                    width: parent.width
                    height: preview.slot === "card" ? Math.min(parent.height, width) : parent.height
                    sourceComponent: preview.slot === "card" ? cardPreview : heroPreview
                }
                Rectangle {
                    anchors.fill: picture
                    anchors.margins: -2
                    radius: 14
                    color: "transparent"
                    border.color: preview.chosen || preview.visualFocus ? Colors.accent : preview.hovered ? Colors.outline : Colors.border
                }
            }
        }
    }
    Component {
        id: cardPreview
        CoverArt {
            instanceId: dialog.instanceId
            screenshot: dialog.info.screenshot || ""
            cover: dialog.controller.coverFor(dialog.instanceId, "card")
            showScreenshot: dialog.controller.screenshotFor(dialog.instanceId, "card")
        }
    }
    Component {
        id: heroPreview
        HeroBackdrop {
            radius: 12
            cover: dialog.controller.coverFor(dialog.instanceId, "hero")
            screenshot: dialog.info.screenshot || ""
            showScreenshot: dialog.controller.screenshotFor(dialog.instanceId, "hero")
            Text {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 16 }
                text: dialog.info.name || ""
                textFormat: Text.PlainText
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: Typography.panelTitle
                elide: Text.ElideRight
            }
        }
    }
    contentItem: ScrollView {
        id: scroll
        implicitHeight: body.implicitHeight
        contentWidth: availableWidth
        contentHeight: body.implicitHeight
        clip: true
        ColumnLayout {
            id: body
            width: scroll.availableWidth
            spacing: 18
            RowLayout {
                Layout.fillWidth: true
                spacing: 8
                Text { text: qsTr("Apply to"); color: Colors.subtext; font.pixelSize: Typography.bodySmall; Layout.rightMargin: 6 }
                Repeater {
                    model: [{ key: "both", label: qsTr("Both images") }, { key: "card", label: qsTr("Card") }, { key: "hero", label: qsTr("Banner") }]
                    delegate: Chip {
                        required property var modelData
                        objectName: "artworkTarget_" + modelData.key
                        interactive: true
                        active: dialog.target === modelData.key
                        tint: active ? Colors.accent : Colors.subtext
                        text: modelData.label
                        onClicked: dialog.target = modelData.key
                    }
                }
                Item { Layout.fillWidth: true }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.preferredHeight: 210
                spacing: 24
                SlotPreview { Layout.preferredWidth: 176; Layout.fillHeight: true; slot: "card"; label: qsTr("Card") }
                SlotPreview { Layout.fillWidth: true; Layout.fillHeight: true; slot: "hero"; label: qsTr("Banner") }
            }
            Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 10
                Text { text: qsTr("Image source"); color: Colors.text; font.pixelSize: Typography.body; font.weight: Font.DemiBold }
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 8
                    Repeater {
                        model: dialog.modes
                        delegate: AbstractButton {
                            id: option
                            required property var modelData
                            readonly property bool chosen: dialog.activeMode === modelData.mode
                            objectName: "artworkMode_" + (modelData.mode || "default")
                            Layout.fillWidth: true
                            Layout.preferredWidth: 1
                            implicitHeight: 70
                            padding: 12
                            hoverEnabled: true
                            enabled: modelData.mode !== "screenshot" || dialog.shots.length > 0
                            Accessible.name: modelData.label
                            onClicked: dialog.apply(modelData.mode)
                            background: Rectangle {
                                radius: 10
                                color: option.chosen ? Colors.surfaceHi : option.hovered ? Colors.inset : "transparent"
                                border.color: option.chosen || option.visualFocus ? Colors.accent : Colors.border
                            }
                            contentItem: ColumnLayout {
                                spacing: 4
                                opacity: option.enabled ? 1 : 0.45
                                Text { Layout.fillWidth: true; text: option.modelData.label; color: Colors.text; font.pixelSize: Typography.bodySmall; font.weight: Font.DemiBold; elide: Text.ElideRight }
                                Text { Layout.fillWidth: true; text: option.enabled ? option.modelData.hint : qsTr("No screenshots yet"); color: Colors.subtext; font.pixelSize: Typography.caption; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                            }
                        }
                    }
                }
            }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: 70
                radius: 10
                color: Colors.inset
                RowLayout {
                    anchors { fill: parent; margins: 12 }
                    spacing: 12
                    LineIcon { Layout.preferredWidth: 22; Layout.maximumWidth: 22; name: "image"; tint: Colors.subtext }
                    ColumnLayout {
                        Layout.fillWidth: true
                        spacing: 4
                        Text { Layout.fillWidth: true; text: dialog.activeMode === "image" ? qsTr("Custom image selected") : qsTr("Use your own image"); color: Colors.text; font.pixelSize: Typography.bodySmall; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: qsTr("PNG, JPEG or WebP"); color: Colors.subtext; font.pixelSize: Typography.caption; elide: Text.ElideRight }
                    }
                    ActionButton { objectName: "artworkChooseImage"; Layout.preferredWidth: 152; Layout.maximumWidth: 152; text: qsTr("Choose image…"); onClicked: picker.open() }
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                visible: dialog.shots.length > 0
                spacing: 10
                Text { text: qsTr("Screenshots"); color: Colors.text; font.pixelSize: Typography.body; font.weight: Font.DemiBold }
                ListView {
                    id: strip
                    Layout.fillWidth: true
                    Layout.preferredHeight: 106
                    orientation: ListView.Horizontal
                    spacing: 10
                    clip: true
                    model: dialog.shots
                    ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                    delegate: AbstractButton {
                        id: thumb
                        required property var modelData
                        width: 144
                        height: 94
                        padding: 3
                        hoverEnabled: true
                        Accessible.name: qsTr("Use %1").arg(modelData.fileName)
                        onClicked: dialog.apply("image", modelData.url)
                        ToolTip.visible: hovered
                        ToolTip.text: modelData.fileName
                        background: Rectangle { radius: 8; color: Colors.inset; border.color: thumb.hovered || thumb.visualFocus ? Colors.accent : Colors.border }
                        contentItem: ColumnLayout {
                            spacing: 4
                            Image { Layout.fillWidth: true; Layout.fillHeight: true; source: thumb.modelData.url; sourceSize.width: 288; fillMode: Image.PreserveAspectCrop; asynchronous: true; clip: true }
                            Text { Layout.fillWidth: true; text: thumb.modelData.fileName; color: Colors.subtext; font.pixelSize: Typography.caption; elide: Text.ElideMiddle }
                        }
                    }
                }
            }
        }
    }
    footer: DialogActions {
        cancelVisible: false
        confirmText: qsTr("Done")
        confirmName: "artworkDone"
        confirmWidth: 112
        onConfirmed: dialog.close()
        TextLink { objectName: "artworkReset"; text: qsTr("Reset to default"); tint: Colors.subtext; onClicked: dialog.apply("") }
        Text { text: qsTr("Changes apply immediately"); color: Colors.subtext; font.pixelSize: Typography.caption }
    }
    FileDialog {
        id: picker
        objectName: "artworkFilePicker"
        title: qsTr("Choose an image")
        currentFolder: StandardPaths.writableLocation(StandardPaths.PicturesLocation)
        nameFilters: [qsTr("Images (*.png *.jpg *.jpeg *.webp)")]
        onAccepted: dialog.apply("image", selectedFile)
    }
}
