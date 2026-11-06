import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import QtQuick.Dialogs

Item {
    id: hero
    required property var controller
    readonly property var contents: controller.details
    readonly property var info: contents.info

    Layout.fillWidth: true
    readonly property bool compact: controller.instanceTab !== "overview"
    Layout.preferredHeight: compact ? 64 : 242
    Behavior on Layout.preferredHeight { NumberAnimation { duration: Colors.animations ? 360 : 0; easing.type: Easing.InOutCubic } }
    HeroBackdrop {
        visible: !hero.compact
        anchors {
            fill: parent
            margins: 0
        }
        cover: controller.coverFor(contents.instanceId, "hero")
        screenshot: hero.info.screenshot || ""
        showScreenshot: controller.screenshotFor(contents.instanceId, "hero")
    }
    ActionButton {
        id: backButton
        objectName: "instanceBackButton"
        anchors { left: parent.left; top: parent.top; leftMargin: 32; topMargin: hero.compact ? 14 : 24 }
        implicitWidth: 100
        implicitHeight: 36
        text: qsTr("Back")
        onClicked: {
            if (hero.controller.canGoBack) hero.controller.back();
            else if (hero.compact) hero.controller.instanceTab = "overview";
            else hero.controller.navigate("library");
        }
        contentItem: Item {
            implicitWidth: backContent.implicitWidth
            implicitHeight: backContent.implicitHeight
            RowLayout {
                id: backContent
                anchors.centerIn: parent
                spacing: 6
                LineIcon { name: "back"; implicitWidth: 16; implicitHeight: 16; tint: Colors.text }
                Text { text: backButton.text; color: Colors.text; font.pixelSize: Typography.body; verticalAlignment: Text.AlignVCenter }
            }
        }
    }
    RowLayout {
        visible: hero.compact
        anchors {
            left: backButton.right
            right: parent.right
            verticalCenter: parent.verticalCenter
            leftMargin: 12
            rightMargin: 32
        }
        spacing: 8
        TextLink {
            Layout.maximumWidth: Math.max(120, hero.width * 0.42)
            text: hero.info.name || ""
            tint: Colors.subtext
            underline: false
            pixelSize: Typography.body
            Accessible.name: "Back to instance overview"
            onClicked: hero.controller.openTab("overview")
        }
        Text {
            text: "/"
            color: Colors.subtext
            font.pixelSize: Typography.body
        }
        Text {
            text: ({ mods: "Mods", resourcepacks: "Resource packs", shaders: "Shaders", worlds: "Worlds", servers: "Servers", screenshots: "Screenshots", logs: "Logs" })[controller.instanceTab] || ""
            color: Colors.text
            font.pixelSize: Typography.body
        }
        Item {
            Layout.fillWidth: true
        }
        TextLink {
            text: "Instance settings"
            onClicked: controller.editSettings(contents.instanceId)
        }
    }
    RowLayout {
        visible: !hero.compact
        anchors {
            left: parent.left
            right: parent.right
            bottom: parent.bottom
            margins: 36
            bottomMargin: hero.compact ? 20 : 28
        }
        spacing: 22
        InstanceIcon {
            size: hero.compact ? 56 : 86
            name: hero.info.name || ""
            icon: hero.info.icon || ""
            loader: hero.info.loader || ""
        }
        ColumnLayout {
            Layout.fillWidth: true
            spacing: 10
            Text {
                Layout.fillWidth: true
                text: hero.info.name || "Instance unavailable"
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: hero.compact ? Typography.heroCompact : Typography.hero
                font.letterSpacing: 1
                elide: Text.ElideRight
                RenameTarget { onRenameRequested: hero.controller.renameInstance(contents.instanceId) }
            }
            Text {
                Layout.fillWidth: true
                text: "Minecraft " + (hero.info.version || "?") + " · " + (hero.info.loader || "") + " " + (hero.info.loaderVersion || "") + " · " + (hero.info.mods || 0) + " mods"
                color: Colors.subtext
                font.pixelSize: Typography.body
                elide: Text.ElideRight
            }
        }
        ActionButton {
            text: controller.preferences.favorites.indexOf(contents.instanceId) >= 0 ? "★" : "☆"
            compact: true
            font.pixelSize: Typography.sectionTitle
            Accessible.name: "Toggle favorite"
            ToolTip.visible: hovered
            ToolTip.text: "Favorite"
            onClicked: controller.preferences.toggleFavorite(contents.instanceId)
        }
        ActionButton {
            compact: true
            Accessible.name: "Open instance folder"
            ToolTip.visible: hovered
            ToolTip.text: "Open folder"
            enabled: !!hero.info.instanceId
            onClicked: controller.instances.openFolder(contents.instanceId)
            LineIcon {
                anchors.centerIn: parent
                name: "folder"
                tint: Colors.subtext
            }
        }
        ActionButton {
            compact: true
            Accessible.name: "Export or share"
            ToolTip.visible: hovered
            ToolTip.text: "Export or share"
            enabled: !!hero.info.instanceId && !!controller.packExporter
            onClicked: controller.exportInstance(contents.instanceId)
            LineIcon {
                anchors.centerIn: parent
                name: "package"
                tint: Colors.subtext
            }
        }
        ActionButton {
            compact: true
            text: "⋯"
            font.pixelSize: Typography.titleSmall
            Accessible.name: "Instance settings"
            ToolTip.visible: hovered
            ToolTip.text: "Instance settings"
            enabled: !!hero.info.instanceId
            onClicked: instanceMenu.popup()
            ThemedMenu {
                id: instanceMenu
                ThemedMenuItem { text: "Instance settings"; onTriggered: controller.editSettings(contents.instanceId) }
                ThemedMenuItem { text: "Rename instance"; onTriggered: controller.renameInstance(contents.instanceId) }
                ThemedMenuItem { text: "Minecraft & loader"; onTriggered: controller.editVersions(contents.instanceId) }
                ThemedMenuItem { text: "Duplicate instance"; onTriggered: controller.duplicateInstance(contents.instanceId) }
                ThemedMenuItem { text: "Open in Prism Launcher…"; visible: controller.prismShortcuts !== false; height: visible ? implicitHeight : 0; onTriggered: controller.instances.editInPrism(contents.instanceId) }
                ThemedMenuItem { text: "Move to group…"; onTriggered: controller.moveToGroup(contents.instanceId) }
            }
        }
        ActionButton {
            text: "▶  PLAY"
            primary: true
            implicitWidth: 180
            enabled: !!hero.info.instanceId
            onClicked: controller.play(contents.instanceId, hero.info.name)
        }
            // Experimental multi-account play; hidden unless enabled in Settings → Experimental.
        ActionButton {
            id: playAs
            objectName: "playAsButton"
            visible: !!controller.altLaunch && controller.preferences.multiAccount
            compact: true
            text: "▾"
            Accessible.name: "Play as another account"
            ToolTip.visible: hovered
            ToolTip.text: "Play as another account (unsafe)"
            enabled: !!hero.info.instanceId
            onClicked: { playAsMenu.copies = controller.altLaunch.altsFor(contents.instanceId); playAsMenu.popup(playAs, 0, playAs.height + 4); }
            ThemedMenu {
                id: playAsMenu
                property var copies: []
                implicitWidth: 300
                ThemedMenuItem { text: "PLAY AS (UNSAFE)"; enabled: false }
                Repeater {
                    model: controller.instances.accounts
                    delegate: ThemedMenuItem {
                        required property var modelData
                        text: modelData.name
                        hint: playAsMenu.copies.some(it => it.account === modelData.name) ? "copy ready" : ""
                        onTriggered: controller.launchAs(contents.instanceId, modelData.name)
                    }
                }
                MenuSeparator { visible: playAsMenu.copies.length > 0; height: visible ? implicitHeight : 0; contentItem: Rectangle { implicitHeight: 1; color: Colors.border } }
                Repeater {
                    model: playAsMenu.copies
                    delegate: ThemedMenuItem {
                        required property var modelData
                        text: "Remove " + modelData.account + "'s copy"
                        danger: true
                        onTriggered: if (controller.altLaunch.removeAlt(modelData.altId)) controller.notify("Copy moved to the trash")
                    }
                }
            }
        }
    }
}
