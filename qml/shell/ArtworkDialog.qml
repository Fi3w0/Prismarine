import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

// Chooses the picture on an instance's library card and on its banner (Home and
// instance page): default, generated artwork, latest screenshot, a screenshot or an image.
MotionDialog {
    id: dialog
    objectName: "artworkDialog"
    required property var controller
    property string instanceId: ""
    // Which picture the options change: "card", "hero" or "both".
    property string target: "both"
    property var shots: []
    readonly property var info: controller.instances.getById(instanceId)
    readonly property var modes: [
        { mode: "", label: "Default", hint: "Follows “Show screenshots” in Settings" },
        { mode: "art", label: "Artwork", hint: "The generated cover in the instance's colour" },
        { mode: "screenshot", label: "Latest screenshot", hint: "Always your newest screenshot" }
    ]
    function openFor(id) {
        instanceId = id;
        target = "both";
        shots = controller.instances.screenshots(id, 24);
        open();
    }
    function apply(mode, url) {
        if (controller.preferences.setArtwork(instanceId, target, mode, url || ""))
            controller.notify(target === "both" ? "Card and banner updated" : target === "card" ? "Card updated" : "Banner updated");
    }
    function modeOf(slot) { return controller.artworkOf(instanceId, slot).mode; }
    // The option highlighted for the current target; mixed when card and banner differ.
    readonly property string activeMode: target === "both" ? (modeOf("card") === modeOf("hero") ? modeOf("card") : "mixed") : modeOf(target)
    title: "Card & banner images"
    subtitle: info.name || ""
    width: Math.min(760, controller.width - 64)
    modal: true

    component SlotPreview: AbstractButton {
        id: preview
        property string slot: "card"
        property string label: ""
        readonly property bool chosen: dialog.target === slot || dialog.target === "both"
        hoverEnabled: true
        onClicked: dialog.target = dialog.target === slot ? "both" : slot
        Accessible.name: "Edit the " + label.toLowerCase()
        contentItem: ColumnLayout {
            spacing: 8
            Item {
                Layout.fillWidth: true
                Layout.fillHeight: true
                Loader {
                    anchors.fill: parent
                    sourceComponent: preview.slot === "card" ? cardPreview : heroPreview
                }
                Rectangle {
                    anchors.fill: parent
                    anchors.margins: -4
                    radius: 16
                    color: "transparent"
                    border.width: 2
                    border.color: preview.chosen ? Colors.accent : preview.hovered ? Colors.border : "transparent"
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Text { text: preview.label; color: preview.chosen ? Colors.text : Colors.subtext; font.pixelSize: 13; font.weight: Font.DemiBold }
                Text {
                    Layout.fillWidth: true
                    horizontalAlignment: Text.AlignRight
                    text: ({ "": "Default", art: "Artwork", screenshot: "Latest screenshot", image: "Custom image" })[dialog.modeOf(preview.slot)] || ""
                    color: Colors.subtext
                    font.pixelSize: 12
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
            Text {
                anchors { left: parent.left; right: parent.right; bottom: parent.bottom; margins: 12 }
                text: dialog.info.name || ""
                color: Colors.artText
                font.family: Colors.displayFont
                font.pixelSize: 16
                wrapMode: Text.Wrap
                maximumLineCount: 2
                elide: Text.ElideRight
            }
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
                anchors { left: parent.left; bottom: parent.bottom; margins: 16 }
                text: dialog.info.name || ""
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: 22
            }
        }
    }

    contentItem: ColumnLayout {
        spacing: 14
        RowLayout {
            Layout.fillWidth: true
            Layout.preferredHeight: 210
            spacing: 18
            SlotPreview { Layout.preferredWidth: 140; Layout.fillHeight: true; slot: "card"; label: "Card" }
            SlotPreview { Layout.fillWidth: true; Layout.fillHeight: true; slot: "hero"; label: "Banner" }
        }
        RowLayout {
            Layout.fillWidth: true
            spacing: 8
            Text { text: "CHANGE"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 12; font.letterSpacing: 2 }
            Repeater {
                model: [{ key: "both", label: "Both" }, { key: "card", label: "Card" }, { key: "hero", label: "Banner" }]
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
        }
        GridLayout {
            Layout.fillWidth: true
            columns: dialog.width >= 700 ? 4 : 2
            columnSpacing: 8
            rowSpacing: 8
            Repeater {
                model: dialog.modes
                delegate: AbstractButton {
                    id: option
                    required property var modelData
                    readonly property bool chosen: dialog.activeMode === modelData.mode
                    objectName: "artworkMode_" + (modelData.mode || "default")
                    Layout.fillWidth: true
                    Layout.preferredWidth: 1
                    implicitHeight: 64
                    padding: 12
                    hoverEnabled: true
                    enabled: modelData.mode !== "screenshot" || dialog.shots.length > 0
                    onClicked: dialog.apply(modelData.mode)
                    background: Rectangle {
                        radius: 10
                        color: option.chosen ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12) : option.hovered ? Colors.surfaceHi : Colors.inset
                        border.color: option.chosen || option.visualFocus ? Colors.accent : Colors.border
                    }
                    contentItem: ColumnLayout {
                        spacing: 2
                        opacity: option.enabled ? 1 : 0.45
                        Text { Layout.fillWidth: true; text: option.modelData.label; color: Colors.text; font.pixelSize: 13; font.weight: Font.DemiBold; elide: Text.ElideRight }
                        Text { Layout.fillWidth: true; text: option.enabled ? option.modelData.hint : "No screenshots yet"; color: Colors.subtext; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                    }
                }
            }
            AbstractButton {
                id: custom
                objectName: "artworkChooseImage"
                readonly property bool chosen: dialog.activeMode === "image"
                Layout.fillWidth: true
                Layout.preferredWidth: 1
                implicitHeight: 64
                padding: 12
                hoverEnabled: true
                onClicked: picker.open()
                background: Rectangle {
                    radius: 10
                    color: custom.chosen ? Qt.rgba(Colors.accent.r, Colors.accent.g, Colors.accent.b, 0.12) : custom.hovered ? Colors.surfaceHi : Colors.inset
                    border.color: custom.chosen || custom.visualFocus ? Colors.accent : Colors.border
                }
                contentItem: ColumnLayout {
                    spacing: 2
                    Text { text: "Choose image…"; color: Colors.text; font.pixelSize: 13; font.weight: Font.DemiBold }
                    Text { Layout.fillWidth: true; text: "PNG, JPG or WebP from your computer"; color: Colors.subtext; font.pixelSize: 11; wrapMode: Text.Wrap; maximumLineCount: 2; elide: Text.ElideRight }
                }
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            visible: dialog.shots.length > 0
            spacing: 8
            Text { text: "OR PICK A SCREENSHOT"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 12; font.letterSpacing: 2 }
            ListView {
                id: strip
                Layout.fillWidth: true
                Layout.preferredHeight: 86
                orientation: ListView.Horizontal
                spacing: 8
                clip: true
                model: dialog.shots
                ScrollBar.horizontal: ScrollBar { policy: ScrollBar.AsNeeded }
                delegate: AbstractButton {
                    id: thumb
                    required property var modelData
                    width: 136
                    height: 76
                    hoverEnabled: true
                    Accessible.name: "Use " + modelData.fileName
                    onClicked: dialog.apply("image", modelData.url)
                    ToolTip.visible: hovered
                    ToolTip.delay: 500
                    ToolTip.text: modelData.fileName
                    background: Rectangle { radius: 8; color: Colors.surfaceHi; border.color: thumb.hovered || thumb.visualFocus ? Colors.accent : Colors.border; border.width: thumb.hovered ? 2 : 1 }
                    contentItem: Image {
                        source: thumb.modelData.url
                        sourceSize.width: 272
                        fillMode: Image.PreserveAspectCrop
                        asynchronous: true
                        clip: true
                    }
                    padding: 2
                }
            }
        }
    }
    footer: DialogActions {
        cancelText: "Reset to default"
        confirmText: "Done"
        confirmWidth: 120
        onCancelled: {
            dialog.controller.preferences.setArtwork(dialog.instanceId, "both", "");
            dialog.controller.notify("Images reset");
        }
        onConfirmed: dialog.close()
    }
    FileDialog {
        id: picker
        title: "Choose an image"
        nameFilters: ["Images (*.png *.jpg *.jpeg *.webp)"]
        onAccepted: dialog.apply("image", selectedFile)
    }
}
