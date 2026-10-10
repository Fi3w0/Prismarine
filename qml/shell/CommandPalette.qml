import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Ctrl+K: one search across instances, worlds, favourite servers, groups, settings and actions.
Popup {
    id: palette
    objectName: "commandPalette"
    required property var controller
    readonly property var win: controller
    property var results: []
    property int current: 0
    function openPalette() {
        field.text = "";
        rebuild();
        open();
        field.forceActiveFocus();
    }
    function matches(haystack, tokens) {
        const text = haystack.toLowerCase();
        return tokens.every(token => text.indexOf(token) >= 0);
    }
    function rebuild() {
        const query = field.text.trim().toLowerCase();
        const tokens = query.split(/\s+/).filter(it => it.length);
        const out = [];
        const add = (item, haystack) => { if (!tokens.length || matches(haystack, tokens)) out.push(item); };
        const instances = win.instances.allInstances;
        for (const it of instances)
            add({ kind: "Instance", title: it.name, detail: (it.loader + " · " + it.version), icon: "library", run: () => win.openInstance(it.instanceId) },
                it.name + " " + it.version + " " + it.loader + " instance open");
        if (tokens.length)
            for (const it of instances)
                add({ kind: "Play", title: "Play " + it.name, detail: it.loader + " · " + it.version, icon: "play", run: () => win.play(it.instanceId, it.name) },
                    "play launch start " + it.name + " " + it.version);
        for (const it of win.instances.worlds)
            add({ kind: "World", title: it.name, detail: "in " + it.instanceName, icon: "world", run: () => { if (win.instances.launchWorld(it.instanceId, it.name)) win.followLaunch(it.instanceId); } },
                "world save " + it.name + " " + it.instanceName);
        for (const it of win.preferences.serverFavorites)
            add({ kind: "Server", title: "Join " + it.name, detail: it.address, icon: "external", run: () => { if (win.instances.launchServer(it.instanceId, it.address)) win.followLaunch(it.instanceId); } },
                "server join multiplayer " + it.name + " " + it.address);
        for (const it of win.instances.groupNames())
            add({ kind: "Group", title: it, detail: "Instance group", icon: "folder", run: () => win.navigate("library") }, "group " + it);
        for (const it of win.settingsSections)
            add({ kind: "Setting", title: it.name, detail: "Settings", icon: "settings", run: () => win.openSettings(it.name) }, "settings preferences " + it.name + " " + it.words);
        const actions = [
            { title: "New instance", words: "create add new instance", run: () => win.createInstance() },
            { title: "Import modpack", words: "import pack mrpack zip file", run: () => win.importPack() },
            { title: "Browse mods and modpacks", words: "browse download modrinth curseforge mods packs shaders", run: () => win.navigate("browse") },
            { title: "New group", words: "create group folder organise", run: () => win.newGroup("") },
            { title: "Refresh library", words: "reload refresh rescan", run: () => win.reloadLibrary() },
            { title: "Accounts and skins", words: "account skin cape microsoft profile", run: () => win.navigate("accounts") },
            { title: "Home", words: "home dashboard news playtime", run: () => win.navigate("home") },
            { title: "Library", words: "library instances", run: () => win.navigate("library") },
            { title: "Open Prism Launcher", words: "prism launcher window", run: () => win.instances.openPrism() }
        ];
        for (const it of actions)
            add({ kind: "Action", title: it.title, detail: "", icon: "plus", run: it.run }, it.title + " " + it.words);
        // Titles that start with the query come first; otherwise the order above holds.
        if (tokens.length)
            out.sort((a, b) => (b.title.toLowerCase().startsWith(query) ? 1 : 0) - (a.title.toLowerCase().startsWith(query) ? 1 : 0));
        results = out.slice(0, 60);
        current = 0;
    }
    function run(index) {
        const item = results[index];
        if (!item) return;
        close();
        item.run();
    }
    parent: Overlay.overlay
    x: Math.round((parent.width - width) / 2)
    y: Math.round(parent.height * 0.14)
    width: Math.min(640, parent.width - 64)
    height: Math.min(520, parent.height * 0.72)
    modal: true
    focus: true
    padding: 0
    Overlay.modal: Rectangle { color: Colors.light ? Qt.rgba(0.08, 0.14, 0.17, 0.32) : Qt.rgba(0.01, 0.03, 0.05, 0.62) }
    enter: Transition { NumberAnimation { property: "opacity"; from: 0; to: 1; duration: Colors.animations ? 140 : 0 } }
    exit: Transition { NumberAnimation { property: "opacity"; to: 0; duration: Colors.animations ? 100 : 0 } }
    background: Rectangle { radius: 16; color: Colors.surface; border.color: Colors.border }
    contentItem: ColumnLayout {
        spacing: 0
        RowLayout {
            Layout.fillWidth: true
            Layout.margins: 14
            spacing: 10
            LineIcon { name: "search"; tint: Colors.accent; implicitWidth: 20; implicitHeight: 20 }
            TextField {
                id: field
                objectName: "paletteInput"
                Layout.fillWidth: true
                placeholderText: "Search instances, worlds, servers, settings and actions…"
                placeholderTextColor: Colors.subtext
                color: Colors.text
                font.pixelSize: 16
                background: Item {}
                onTextChanged: palette.rebuild()
                Keys.onDownPressed: { palette.current = Math.min(palette.current + 1, palette.results.length - 1); list.positionViewAtIndex(palette.current, ListView.Contain); }
                Keys.onUpPressed: { palette.current = Math.max(palette.current - 1, 0); list.positionViewAtIndex(palette.current, ListView.Contain); }
                Keys.onReturnPressed: palette.run(palette.current)
                Keys.onEnterPressed: palette.run(palette.current)
                Keys.onEscapePressed: palette.close()
            }
            Text { text: "Esc"; color: Colors.subtext; font.pixelSize: 11 }
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
        ListView {
            id: list
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 6
            clip: true
            model: palette.results
            spacing: 2
            ScrollBar.vertical: ScrollBar {}
            delegate: ItemDelegate {
                id: result
                required property var modelData
                required property int index
                width: ListView.view.width
                height: 48
                highlighted: index === palette.current
                onClicked: palette.run(index)
                onHoveredChanged: if (hovered) palette.current = index
                background: Rectangle {
                    radius: 10
                    color: result.highlighted ? Colors.surfaceHi : "transparent"
                    Rectangle { visible: result.highlighted; x: 0; y: 10; width: 3; height: parent.height - 20; radius: 2; color: Colors.accent }
                }
                contentItem: RowLayout {
                    spacing: 12
                    LineIcon { name: result.modelData.icon; tint: result.highlighted ? Colors.accent : Colors.subtext; implicitWidth: 18; implicitHeight: 18 }
                    Text { text: result.modelData.title; color: Colors.text; font.pixelSize: 14; elide: Text.ElideRight; Layout.maximumWidth: list.width * 0.55 }
                    Text { Layout.fillWidth: true; text: result.modelData.detail; color: Colors.subtext; font.pixelSize: 12; elide: Text.ElideRight }
                    Text { text: result.modelData.kind.toUpperCase(); color: Colors.brass; font.pixelSize: 10; font.letterSpacing: 1.5 }
                }
            }
            Text {
                anchors.centerIn: parent
                visible: !palette.results.length
                text: "Nothing matches “" + field.text + "”"
                color: Colors.subtext
                font.pixelSize: 13
            }
        }
    }
}
