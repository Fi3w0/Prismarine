pragma Singleton
import QtQuick

QtObject {
    // "deep" (default), "light", or "system", which follows the desktop colour scheme.
    property string theme: "deep"
    readonly property bool light: theme === "light" || (theme === "system" && Application.styleHints.colorScheme === Qt.ColorScheme.Light)

    readonly property color base: light ? "#eef1ee" : "#0a1016"
    readonly property color mantle: light ? "#e3e9e6" : "#0d151c"
    readonly property color surface: light ? "#f8faf8" : "#0f1820"
    readonly property color surfaceHi: light ? "#e2ebe8" : "#16222c"
    // Alternating rows and inset rows inside panels.
    readonly property color rowAlt: light ? "#eef3f1" : "#13212a"
    readonly property color inset: light ? "#edf2f0" : "#111e26"
    readonly property color border: light ? "#c9d6d2" : "#22323f"
    readonly property color text: light ? "#14232b" : "#e8f0f4"
    readonly property color subtext: light ? "#55697a" : "#93a6b5"
    readonly property color bone: light ? "#1b3a36" : "#f3ead6"
    readonly property color brass: light ? "#8a7040" : "#c9b88f"
    readonly property color danger: light ? "#c43d3d" : "#f07070"
    readonly property color warning: light ? "#b4621c" : "#f0a35e"
    readonly property color success: light ? "#3f8a32" : "#8cca72"
    // Hero banners and the welcome screen: deep teal at night, sea glass by day.
    readonly property color hero: light ? "#d5ece6" : "#0d2b29"
    readonly property color heroLine: light ? "#9cc7bc" : "#344b42"
    // Text drawn over cover artwork, which stays dark in every theme.
    readonly property color artText: "#f3ead6"
    readonly property color artSubtext: "#c9d4da"
    readonly property string displayFont: "Marcellus SC"
    readonly property string pixelFont: "Silkscreen"
    // The chosen accent; text-on-light needs a deeper shade of it for contrast.
    property color userAccent: "#46d1bb"
    readonly property color accent: light ? Qt.darker(userAccent, 1.55) : userAccent
    property bool animations: true
    property bool decoFrames: true
    readonly property color accentDark: light ? Qt.darker(userAccent, 2.0) : "#2b8a80"
    readonly property color accentInk: light ? "#ffffff" : "#06231f"

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

    function loaderColor(loader) {
        const dark = {
            NeoForge: "#f2a65e",
            Forge: "#d9b25c",
            Fabric: "#d8c39a",
            Quilt: "#b892f2"
        };
        const shade = dark[loader] || "#86c96f";
        return light ? Qt.darker(shade, 1.7) : shade;
    }
}
