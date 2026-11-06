import QtQuick

QtObject {
    id: palette
    property var overrides: ({})
    function token(role, fallback) { return (overrides[light ? "light" : "deep"] || {})[role] || fallback; }
    function readableInk(colour) {
        function luminance(c) {
            function linear(v) { return v <= 0.04045 ? v / 12.92 : Math.pow((v + 0.055) / 1.055, 2.4); }
            return 0.2126 * linear(c.r) + 0.7152 * linear(c.g) + 0.0722 * linear(c.b);
        }
        const value = luminance(colour), dark = luminance(Qt.color("#06211d"));
        if ((Math.max(value, dark) + 0.05) / (Math.min(value, dark) + 0.05) >= 4.5) return "#06211d";
        return 1.05 / (value + 0.05) >= 4.5 ? "#ffffff" : "#000000";
    }
    // "deep" (default), "light", or "system", which follows the desktop colour scheme.
    property int systemMode: 0
    property string theme: "deep"
    readonly property bool light: theme === "light" || (theme === "system" && (systemMode === 1 || (systemMode === 0 && Application.styleHints.colorScheme === Qt.ColorScheme.Light)))

    readonly property color rail: token("rail", light ? "#e3e9e6" : "#070f17")
    readonly property color base: token("base", light ? "#eef1ee" : "#0d1822")
    readonly property color mantle: token("mantle", light ? "#e3e9e6" : "#101e2a")
    readonly property color surface: token("surface", light ? "#f8faf8" : "#142331")
    readonly property color surfaceHi: token("surfaceHi", light ? "#e2ebe8" : "#1a2d3d")
    // Alternating rows and inset rows inside panels.
    readonly property color rowAlt: token("rowAlt", light ? "#eef3f1" : "#182a39")
    readonly property color inset: token("inset", light ? "#edf2f0" : "#162735")
    // Decorative separators. Fields use outline, which stays at least 3:1 on every surface.
    readonly property color border: token("border", light ? "#c9d6d2" : "#263b4d")
    readonly property color outline: token("outline", light ? "#6a7d79" : "#64808f")
    readonly property color text: token("text", light ? "#14232b" : "#e8f1f2")
    readonly property color subtext: token("subtext", light ? "#55697a" : "#93a8b3")
    readonly property color bone: token("bone", light ? "#1b3a36" : "#f3ead6")
    readonly property color brass: token("brass", light ? "#8a7040" : "#c9b88f")
    readonly property color danger: token("danger", light ? "#c43d3d" : "#f07c7c")
    readonly property color warning: token("warning", light ? "#b4621c" : "#f2a65a")
    readonly property color success: token("success", light ? "#3f8a32" : "#8cca72")
    // Hero banners and the welcome screen: deep teal at night, sea glass by day.
    readonly property color hero: token("hero", light ? "#d5ece6" : "#0d2b29")
    readonly property color heroLine: token("heroLine", light ? "#9cc7bc" : "#344b42")
    // Text drawn over cover artwork, which stays dark in every theme.
    readonly property color artText: "#f3ead6"
    readonly property color artSubtext: "#c9d4da"
    readonly property string displayFont: "Marcellus SC"
    readonly property string pixelFont: "Silkscreen"
    // The chosen accent; text-on-light needs a deeper shade of it for contrast.
    property color userAccent: "#46d1bb"
    readonly property color accent: light ? Qt.darker(userAccent, 2.0) : userAccent
    property string cornerStyle: "rounded"
    readonly property int controlRadius: cornerStyle === "angular" ? 2 : 10
    property bool animations: true
    readonly property int motionFeedbackDuration: 120
    readonly property int motionEnterDuration: 180
    readonly property int motionExitDuration: 140
    readonly property int motionPageDuration: 200
    readonly property real motionSlideDistance: 12
    property bool decoFrames: true
    readonly property color accentDark: Qt.darker(accent, 1.15)
    readonly property color accentInk: token("accentInk", readableInk(accent))

    // Categorical chart slots in fixed order, validated for colour-blind separation on
    // surface in each theme. Text never uses these; they mark identity beside a label.
    readonly property var series: light ? ["#2a78d6", "#eb6834", "#1baf7a", "#eda100", "#e87ba4", "#008300"]
                                        : ["#3987e5", "#d95926", "#199e70", "#c98500", "#d55181", "#008300"]
    readonly property color seriesOther: light ? "#a3b1ad" : "#4a5b66"

    function formatBytes(bytes) {
        const units = ["B", "KB", "MB", "GB", "TB"];
        let value = Math.max(0, bytes || 0), unit = 0;
        while (value >= 1024 && unit < units.length - 1) { value /= 1024; ++unit; }
        return (unit === 0 || value >= 100 ? Math.round(value) : value.toFixed(1)) + " " + units[unit];
    }

    function coverColor(id) {
        const palette = ["#46d1bb", "#b892f2", "#f0a35e", "#7aa2ff", "#e07a9a", "#e3c35c", "#8cca72"];
        let hash = 0;
        for (let i = 0; i < id.length; ++i)
            hash = (hash * 31 + id.charCodeAt(i)) >>> 0;
        return palette[hash % palette.length];
    }

    function loaderColor(loader, overArt = false) {
        const dark = {
            NeoForge: "#f2a65e",
            Forge: "#d9b25c",
            Fabric: "#d8c39a",
            Quilt: "#b892f2"
        };
        const shade = dark[loader] || "#86c96f";
        return light && !overArt ? Qt.darker(shade, 1.7) : shade;
    }
}
