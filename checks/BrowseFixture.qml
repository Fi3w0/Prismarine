import QtQuick
import QtQuick.Controls

ApplicationWindow {
    id: host
    width: 960
    height: 640
    visible: true
    color: Colors.base
    property bool lightTheme: false
    onLightThemeChanged: Colors.theme = lightTheme ? "light" : "deep"
    property var details: ({instanceId: "alpha"})
    property var current: ({})
    property string pendingBrowseType: ""
    property string pendingBrowseWorld: ""
    property string pendingBrowseQuery: ""
    property var reviews: []
    property alias downloads: selection
    property QtObject instances: QtObject {
        property var allInstances: [
            {instanceId: "alpha", name: "Ocean exploration", version: "1.21.1", loader: "Fabric"},
            {instanceId: "beta", name: "Building together", version: "1.20.1", loader: "Forge"}
        ]
        property var worlds: [{instanceId: "alpha", name: "Survival"}]
        function getById(id) { return allInstances.find(it => it.instanceId === id) || {}; }
    }
    property QtObject catalog: QtObject {
        property string provider: "modrinth"
        property bool curseForgeReady: false
        property bool loading: false
        property bool versionsLoading: false
        property string error: ""
        property var categoryTags: []
        property var project: ({plainText: true, body: "A compatible project for your next adventure.\n\n".repeat(100)})
        property var results: [{project_id: "ocean", title: "Ocean discoveries", description: "More to explore", author: "Demo author"}]
        property var versions: [{id: "latest", name: "Latest release", dependencies: []}, {id: "older", name: "Earlier release", dependencies: []}]
        signal credentialsChanged()
        function loadCategories() {}
        function categoriesFor(type) { return []; }
        function search(query, version, loader, type, categories) {}
        function loadVersions(id, version, loader) {}
        function loadProject(id) {}
    }
    DownloadSelection { id: selection }
    function reviewInstall(id, version, type, world) { reviews = reviews.concat([{target: id, version: version.id, type: type, world: world}]); }
    function reviewSelection(id, type, world) { reviews = reviews.concat([{target: id, type: type, world: world, count: downloads.items(id, type).length}]); }
    function installPackVersion(version) {}
    BrowsePage { anchors.fill: parent; controller: host }
    Component.onCompleted: { Colors.animations = false; Colors.theme = lightTheme ? "light" : "deep"; }
}
