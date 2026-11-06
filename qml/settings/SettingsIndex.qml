import QtQuick

// Settings sections with search words, shared by the Settings sidebar and Ctrl+K.
QtObject {
    readonly property var sections: [
        { group: "Prismarine", name: "Interface", words: "friends hide tab scroll speed wheel mouse theme accent colour color dark light system animations motion size scale start page home sections background palette surfaces rail text contrast hue hsv hex while playing minimize hide console" },
        { group: "Prismarine", name: "Library & covers", words: "covers rows list sort screenshots sidebar view density frames cover size badges" },
        { group: "Launcher", name: "Launcher mode", words: "full stable mode engine update remove delete uninstall prism handheld shortcuts" },
        { group: "Launcher", name: "Prism integration", words: "classic prism progress desktop window rule program executable" },
        { group: "Launcher", name: "Java & game", words: "java memory ram jvm arguments runtime temurin wrapper launch command" },
        { group: "Launcher", name: "Network", words: "proxy socks http downloads parallel timeout retries token modrinth curseforge key user agent metadata mirror" },
        { group: "Launcher", name: "Storage", words: "disk space clean cleanup logs cache worlds trash shared duplicates hard links" },
        { group: "Launcher", name: "Accounts", words: "account skin cape microsoft profile sign in" },
        { group: "Other", name: "Experimental", words: "multi-account alt accounts unsafe" },
        { group: "Other", name: "About", words: "version licence license credits" }
    ]
}
