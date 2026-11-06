import QtQuick

QtObject {
    id: draft
    required property var preferences
    property var paletteOverrides: ({})
    property color accentColor: "#46d1bb"
    property string theme: "deep"
    property string cornerStyle: "rounded"
    property int interfaceSize: 100
    property string libraryDensity: "comfortable"
    property int coverSize: 0
    property bool showCoverBadges: true
    property string libraryView: "covers"
    property string startPage: "library"
    property var homeSections: []
    property bool animations: true
    property bool showScreenshots: false
    property bool decoFrames: true
    property string whilePlaying: "keep"
    property bool prismConsole: false
    property bool friendsEnabled: false
    property int scrollSpeed: 2
    property bool controllerEnabled: true
    readonly property var defaults: ({paletteOverrides: {}, accentColor: "#46d1bb", theme: "deep", cornerStyle: "rounded", interfaceSize: 100,
        libraryDensity: "comfortable", coverSize: 0, showCoverBadges: true, libraryView: "covers", startPage: "library",
        homeSections: ["recent", "servers", "worlds", "stats", "news", "playtime"], animations: true,
        showScreenshots: false, decoFrames: true, whilePlaying: "keep", prismConsole: false, friendsEnabled: false, scrollSpeed: 2, controllerEnabled: true})
    property var baseline: ({})
    readonly property bool dirty: Object.keys(defaults).some(key => fingerprint(key, draft[key]) !== baseline[key])
    function fingerprint(key, value) {
        if (key === "paletteOverrides") {
            const sorted = {};
            for (const theme of Object.keys(value || {}).sort()) {
                sorted[theme] = {};
                for (const role of Object.keys(value[theme]).sort()) sorted[theme][role] = value[theme][role];
            }
            return JSON.stringify(sorted);
        }
        if (key === "homeSections") return value.slice().sort().join(",");
        return String(value);
    }
    function load() {
        // QML colours can be live value references; keep an immutable comparison.
        const snapshot = {};
        for (const key of Object.keys(defaults)) { draft[key] = preferences[key]; snapshot[key] = fingerprint(key, draft[key]); }
        baseline = snapshot;
    }
    function resetDefaults() { for (const key of Object.keys(defaults)) draft[key] = defaults[key]; }
    function apply() {
        for (const key of Object.keys(defaults))
            if (fingerprint(key, preferences[key]) !== fingerprint(key, draft[key])) preferences[key] = draft[key];
        preferences.sync();
        load();
    }
    Component.onCompleted: load()
}
