import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Settings → About: the app, its author, this installation, and credits.
ColumnLayout {
    id: about
    required property var controller
    required property string section
    readonly property var info: controller.appInfo || ({})
    readonly property string github: "https://github.com/Fi3w0"
    readonly property var paths: [
        { label: "Prism data", path: controller.instances.dataDir },
        { label: "Instances", path: controller.instances.instanceDir },
        { label: "Prismarine settings", path: controller.preferences.fileName || "" },
        { label: "Prismarine data", path: info.appData || "" }
    ]
    readonly property var system: [
        { label: "Version", value: "Prismarine " + Qt.application.version },
        { label: "Qt", value: info.qtRuntime ? info.qtRuntime + (info.qtBuild !== info.qtRuntime ? " (built with " + info.qtBuild + ")" : "") : "" },
        { label: "System", value: info.system || "" },
        { label: "Kernel", value: info.kernel ? info.kernel + " · " + info.architecture : "" },
        { label: "Compiler", value: info.compiler || "" }
    ].filter(it => !!it.value)
    readonly property string modrinth: "https://modrinth.com/user/Fi3w0"
    readonly property var projects: [
        { name: "Fiw Bosses", stack: "Fabric · NeoForge · Forge", text: "Data-driven custom bosses: multi-phase fights, minions and 50+ abilities from JSON, with hot reload.", url: "https://modrinth.com/mod/fiw-bosses" },
        { name: "Fiw AntiCheat", stack: "Fabric · NeoForge · Forge", text: "Mod verification, modpack enforcement and anti-cheat tools for server admins.", url: "https://modrinth.com/mod/fiw-anticheat" },
        { name: "Fiw Custom Items", stack: "Fabric · NeoForge", text: "Custom items from JSON: NBT, attributes and configurable abilities, no coding and no restarts.", url: "https://modrinth.com/mod/fiw-custom-items" },
        { name: "Fiw Admin Utilities", stack: "Fabric · NeoForge · Forge", text: "Maintenance mode, lag watchdog, entity sweep, vanish and more in one lightweight server mod.", url: "https://modrinth.com/mod/fiw-admin-utilitys" }
    ]
    readonly property var credits: [
        { name: "Prism Launcher", note: "Sign-in, game setup and launching · GPL-3.0", url: "https://prismlauncher.org" },
        { name: "Qt 6", note: "Interface, networking and concurrency · LGPL-3.0", url: "https://www.qt.io" },
        { name: "libarchive", note: "Reading jars and modpacks · BSD-2-Clause", url: "https://libarchive.org" },
        { name: "OpenSSL", note: "Signatures for Friends · Apache-2.0", url: "https://www.openssl.org" },
        { name: "QtKeychain", note: "System keyring storage · BSD-3-Clause", url: "https://github.com/frankosterfeld/qtkeychain" },
        { name: "Modrinth & CurseForge", note: "Project search, downloads and update checks", url: "https://modrinth.com" },
        { name: "Outfit, Marcellus SC, Silkscreen", note: "Fonts · SIL Open Font License 1.1", url: "https://fonts.google.com" }
    ]
    function systemReport() {
        return system.map(it => it.label + ": " + it.value).concat(paths.map(it => it.label + ": " + it.path)).join("\n");
    }

    Layout.fillWidth: true
    visible: section === "About"
    spacing: 18

    component Card: Rectangle {
        default property alias content: inner.data
        property alias spacing: inner.spacing
        Layout.fillWidth: true
        implicitHeight: inner.implicitHeight + 40
        radius: 14
        color: Colors.surface
        border.color: Colors.border
        ColumnLayout {
            id: inner
            anchors { fill: parent; margins: 20 }
            spacing: 12
        }
    }
    component Heading: Text {
        color: Colors.brass
        font.family: Colors.displayFont
        font.pixelSize: 12
        font.letterSpacing: 2
    }

    // The app
    Rectangle {
        Layout.fillWidth: true
        implicitHeight: hero.implicitHeight + 48
        radius: 16
        color: Colors.hero
        border.color: Colors.heroLine
        RowLayout {
            id: hero
            anchors { fill: parent; margins: 24 }
            spacing: 24
            Image {
                objectName: "aboutLogo"
                source: "qrc:/assets/logos/" + about.controller.logoFile
                Layout.preferredWidth: 96
                Layout.preferredHeight: 96
                Layout.alignment: Qt.AlignTop
                sourceSize.width: 192
                sourceSize.height: 192
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 8
                RowLayout {
                    spacing: 12
                    Text { text: "Prismarine"; color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: 36 }
                    Chip { text: "v" + Qt.application.version; tint: Colors.accent }
                }
                Text {
                    Layout.fillWidth: true
                    text: "A native Qt 6 home for your Minecraft library, built on top of your existing Prism Launcher installation. Prismarine manages instances, mods, worlds and content; Prism still handles Microsoft sign-in, game files and launching."
                    color: Colors.subtext
                    font.pixelSize: 14
                    lineHeight: 1.25
                    wrapMode: Text.Wrap
                }
                Flow {
                    Layout.fillWidth: true
                    Layout.topMargin: 6
                    spacing: 10
                    ActionButton { text: "Open Prism Launcher"; onClicked: about.controller.instances.openPrism() }
                    ActionButton { text: "Prism Launcher website  ↗"; onClicked: Qt.openUrlExternally("https://prismlauncher.org") }
                }
            }
        }
    }

    // The author
    Card {
        Heading { text: "MADE BY" }
        RowLayout {
            Layout.fillWidth: true
            spacing: 16
            // Round avatar from GitHub, drawn with a circular clip; a letter while offline.
            Canvas {
                id: avatar
                readonly property string url: "https://avatars.githubusercontent.com/u/98111375?s=128"
                property bool ready: false
                implicitWidth: 64
                implicitHeight: 64
                Component.onCompleted: loadImage(url)
                onImageLoaded: { ready = isImageLoaded(url); requestPaint(); }
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.beginPath();
                    ctx.arc(width / 2, height / 2, width / 2 - 2, 0, Math.PI * 2);
                    ctx.closePath();
                    ctx.fillStyle = Colors.surfaceHi;
                    ctx.fill();
                    if (ready) {
                        ctx.save();
                        ctx.clip();
                        ctx.drawImage(url, 2, 2, width - 4, height - 4);
                        ctx.restore();
                    }
                    ctx.lineWidth = 2;
                    ctx.strokeStyle = Colors.accent;
                    ctx.stroke();
                }
                Text {
                    anchors.centerIn: parent
                    visible: !avatar.ready
                    text: "F"
                    color: Colors.accent
                    font.family: Colors.displayFont
                    font.pixelSize: 28
                }
            }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 3
                RowLayout {
                    spacing: 8
                    Text { text: "Fi3w0 · Fiw Labs"; color: Colors.text; font.pixelSize: 18; font.weight: Font.DemiBold }
                }
                Text {
                    Layout.fillWidth: true
                    text: "Minecraft server mods, Linux and Qt tooling. Gentoo on the desktop, Wayland compositors, and whatever else comes to mind."
                    color: Colors.subtext
                    font.pixelSize: 13
                    wrapMode: Text.Wrap
                }
            }
        }
        Flow {
            Layout.fillWidth: true
            spacing: 10
            ActionButton { text: "GitHub  ↗"; onClicked: Qt.openUrlExternally(about.github) }
            ActionButton { text: "Modrinth  ↗"; onClicked: Qt.openUrlExternally(about.modrinth) }
            ActionButton { text: "fiwlabs.dev  ↗"; onClicked: Qt.openUrlExternally("https://fiwlabs.dev") }
            ActionButton { text: "♥  Support on Ko-fi"; primary: true; onClicked: Qt.openUrlExternally("https://ko-fi.com/fi3w0") }
        }
    }

    // Other projects
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 4
        Heading { Layout.fillWidth: true; text: "MINECRAFT MODS BY FI3W0" }
        TextLink { text: "All projects on Modrinth  ↗"; pixelSize: 12; onClicked: Qt.openUrlExternally(about.modrinth) }
    }
    GridLayout {
        Layout.fillWidth: true
        columns: about.width >= 760 ? 2 : 1
        columnSpacing: 12
        rowSpacing: 12
        Repeater {
            model: about.projects
            delegate: AbstractButton {
                id: project
                required property var modelData
                Layout.fillWidth: true
                Layout.fillHeight: true
                Layout.preferredWidth: 1
                implicitHeight: projectBody.implicitHeight + 32
                hoverEnabled: true
                Accessible.name: modelData.name + ", opens Modrinth"
                onClicked: Qt.openUrlExternally(modelData.url)
                HoverHandler { cursorShape: Qt.PointingHandCursor }
                background: Rectangle {
                    radius: 12
                    color: project.hovered ? Colors.surfaceHi : Colors.surface
                    border.color: project.hovered || project.visualFocus ? Colors.accent : Colors.border
                    Behavior on color { ColorAnimation { duration: Colors.animations ? 140 : 0 } }
                }
                contentItem: ColumnLayout {
                    id: projectBody
                    spacing: 4
                    RowLayout {
                        Layout.fillWidth: true
                        Text { Layout.fillWidth: true; text: project.modelData.name; color: Colors.text; font.pixelSize: 15; font.weight: Font.DemiBold }
                        Text { text: "↗"; color: project.hovered ? Colors.accent : Colors.subtext; font.pixelSize: 14 }
                    }
                    Text { text: project.modelData.stack; color: Colors.brass; font.pixelSize: 11; font.letterSpacing: 0.5 }
                    Text { Layout.fillWidth: true; text: project.modelData.text; color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.Wrap; lineHeight: 1.2 }
                    // Keeps a shorter card's text at the top when its neighbour is taller.
                    Item { Layout.fillHeight: true }
                }
                padding: 16
            }
        }
    }

    // This installation
    Card {
        RowLayout {
            Layout.fillWidth: true
            Heading { Layout.fillWidth: true; text: "THIS INSTALLATION" }
            TextLink {
                objectName: "copySystemInfo"
                text: "Copy system info"
                pixelSize: 12
                onClicked: {
                    clipboard.text = about.systemReport();
                    clipboard.selectAll();
                    clipboard.copy();
                    about.controller.notify("System info copied");
                }
            }
        }
        // Hidden helper: QML has no clipboard API, but TextEdit can copy.
        TextEdit { id: clipboard; visible: false }
        GridLayout {
            Layout.fillWidth: true
            columns: 2
            columnSpacing: 20
            rowSpacing: 8
            Repeater {
                model: about.system
                delegate: Text {
                    required property var modelData
                    required property int index
                    Layout.row: index
                    Layout.column: 0
                    text: modelData.label
                    color: Colors.subtext
                    font.pixelSize: 12
                }
            }
            Repeater {
                model: about.system
                delegate: Text {
                    required property var modelData
                    required property int index
                    Layout.row: index
                    Layout.column: 1
                    Layout.fillWidth: true
                    text: modelData.value
                    color: Colors.text
                    font.pixelSize: 12
                    elide: Text.ElideRight
                }
            }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
        Repeater {
            model: about.paths.filter(it => !!it.path)
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 12
                Text { Layout.preferredWidth: 150; text: modelData.label; color: Colors.subtext; font.pixelSize: 12 }
                Text { Layout.fillWidth: true; text: modelData.path; color: Colors.text; font.pixelSize: 12; elide: Text.ElideMiddle }
                TextLink {
                    text: "Open"
                    pixelSize: 12
                    Accessible.name: "Open " + modelData.label
                    // A settings file opens its folder.
                    // "file:///" + path without its leading slash works for /home/… and C:/… alike.
                    onClicked: Qt.openUrlExternally("file:///" + (modelData.path.endsWith(".ini") ? modelData.path.substring(0, modelData.path.lastIndexOf("/")) : modelData.path).replace(/^\/+/, ""))
                }
            }
        }
    }

    // Credits
    Card {
        spacing: 8
        Heading { text: "BUILT WITH" }
        Repeater {
            model: about.credits
            delegate: RowLayout {
                required property var modelData
                Layout.fillWidth: true
                spacing: 12
                Item {
                    Layout.preferredWidth: 220
                    implicitHeight: creditLink.implicitHeight
                    TextLink { id: creditLink; text: modelData.name; pixelSize: 13; underline: false; onClicked: Qt.openUrlExternally(modelData.url) }
                }
                Text { Layout.fillWidth: true; text: modelData.note; color: Colors.subtext; font.pixelSize: 12; elide: Text.ElideRight }
            }
        }
    }

    // License
    Card {
        spacing: 8
        Heading { text: "LICENSE" }
        Text {
            Layout.fillWidth: true
            text: "Prismarine is free software: you can redistribute it and/or modify it under the terms of the GNU General Public License, version 3 only (GPL-3.0-only). It comes with ABSOLUTELY NO WARRANTY."
            color: Colors.text
            font.pixelSize: 13
            wrapMode: Text.Wrap
            lineHeight: 1.2
        }
        Text {
            Layout.fillWidth: true
            text: "The Prismarine logos are artwork by Fi3w0 under CC BY-NC-ND 4.0, not the GPL. The name and logos identify the official app, so forks must use their own."
            color: Colors.subtext
            font.pixelSize: 12
            wrapMode: Text.Wrap
        }
        Flow {
            Layout.fillWidth: true
            spacing: 16
            TextLink { text: "GNU GPL v3  ↗"; pixelSize: 12; onClicked: Qt.openUrlExternally("https://www.gnu.org/licenses/gpl-3.0.html") }
            TextLink { text: "Logo license (CC BY-NC-ND 4.0)  ↗"; pixelSize: 12; onClicked: Qt.openUrlExternally("https://creativecommons.org/licenses/by-nc-nd/4.0/") }
            TextLink { text: "Name & logo policy  ↗"; pixelSize: 12; onClicked: Qt.openUrlExternally("https://github.com/Fi3w0") }
        }
    }

    Text {
        Layout.fillWidth: true
        Layout.topMargin: 4
        text: "© 2026 Fi3w0. Not an official Minecraft product. Not approved by or associated with Mojang or Microsoft. Prismarine is an independent project and is not affiliated with the Prism Launcher team."
        color: Colors.subtext
        font.pixelSize: 11
        wrapMode: Text.Wrap
        opacity: 0.8
    }
}
