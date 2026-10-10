import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

// Settings → Network: Prism's proxy, download and API settings (prismlauncher.cfg).
ColumnLayout {
    id: form
    required property var controller
    readonly property var service: controller.network
    property var draft: ({})
    // Secrets typed here are sent once on save and never read back.
    property var secrets: ({})
    function reset() {
        draft = service ? Object.assign({}, service.values) : {};
        secrets = {};
    }
    function change(key, value) {
        const next = Object.assign({}, draft);
        next[key] = value;
        draft = next;
    }
    function secret(key, value) {
        const next = Object.assign({}, secrets);
        next[key] = value;
        secrets = next;
    }
    function save() {
        if (!service.save(Object.assign({}, draft, secrets))) return;
        controller.notify(controller.instances.prismRunning() ? "Network settings saved · restart Prism to apply them there" : "Network settings saved");
    }
    Component.onCompleted: reset()
    Connections {
        target: form.service
        ignoreUnknownSignals: true
        function onChanged() { form.reset(); }
    }
    spacing: 14
    visible: !!service

    component Heading: Text {
        color: Colors.brass
        font.family: Colors.displayFont
        font.letterSpacing: 2
        font.pixelSize: 13
        Layout.topMargin: 10
    }
    component Hint: Text {
        Layout.fillWidth: true
        color: Colors.subtext
        font.pixelSize: 12
        wrapMode: Text.Wrap
    }
    component Field: ColumnLayout {
        id: field
        property string label: ""
        property string key: ""
        property string placeholder: ""
        property bool numeric: false
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 6
        opacity: enabled ? 1 : 0.55
        Text { text: field.label; color: Colors.text; font.pixelSize: 13 }
        InputField {
            Layout.fillWidth: true
            objectName: "network_" + field.key
            text: form.draft[field.key] || ""
            placeholderText: field.placeholder
            Accessible.name: field.label
            inputMethodHints: field.numeric ? Qt.ImhDigitsOnly : Qt.ImhNone
            validator: field.numeric ? digits : null
            onTextEdited: form.change(field.key, text)
        }
    }
    component SecretField: ColumnLayout {
        id: secretField
        property string label: ""
        property string key: ""
        property string hasKey: ""
        property string clearKey: ""
        readonly property bool stored: !!form.draft[hasKey] && !form.secrets[clearKey]
        Layout.fillWidth: true
        Layout.preferredWidth: 1
        spacing: 6
        RowLayout {
            Text { Layout.fillWidth: true; text: secretField.label; color: Colors.text; font.pixelSize: 13 }
            TextLink {
                visible: secretField.stored
                text: "Remove"
                tint: Colors.danger
                pixelSize: 12
                onClicked: form.secret(secretField.clearKey, true)
            }
        }
        InputField {
            Layout.fillWidth: true
            echoMode: TextInput.Password
            text: form.secrets[secretField.key] || ""
            placeholderText: secretField.stored ? "Saved — type to replace" : form.secrets[secretField.clearKey] ? "Will be removed" : "Not set"
            Accessible.name: secretField.label
            onTextEdited: { form.secret(secretField.key, text); if (text) form.secret(secretField.clearKey, false); }
        }
    }
    IntValidator { id: digits; bottom: 0; top: 99999 }

    Hint {
        visible: form.controller.instances.prismRunning()
        text: "Prism Launcher is open. It reads these settings at startup and may overwrite them when you change settings in its window, so restart it after saving."
        color: Colors.warning
    }
    Heading { text: "PROXY" }
    Hint { text: "Used by Prism for every download and sign-in, and by Prismarine for browsing, news and updates." }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            spacing: 6
            Text { text: "Type"; color: Colors.text; font.pixelSize: 13 }
            SelectBox {
                objectName: "proxyType"
                Layout.fillWidth: true
                readonly property var keys: ["None", "Default", "SOCKS5", "HTTP"]
                model: ["No proxy", "System proxy", "SOCKS5", "HTTP"]
                currentIndex: Math.max(0, keys.indexOf(form.draft.proxyType || "None"))
                onActivated: index => form.change("proxyType", keys[index])
            }
        }
        Field { label: "Address"; key: "proxyAddr"; placeholder: "127.0.0.1"; enabled: form.draft.proxyType === "SOCKS5" || form.draft.proxyType === "HTTP" }
        Field { label: "Port"; key: "proxyPort"; numeric: true; placeholder: "8080"; Layout.preferredWidth: 0.5; enabled: form.draft.proxyType === "SOCKS5" || form.draft.proxyType === "HTTP" }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        enabled: form.draft.proxyType === "SOCKS5" || form.draft.proxyType === "HTTP"
        opacity: enabled ? 1 : 0.55
        Field { label: "Username"; key: "proxyUser"; placeholder: "Optional" }
        SecretField { label: "Password"; key: "proxyPass"; hasKey: "hasProxyPass"; clearKey: "clearProxyPass" }
    }

    Heading { text: "DOWNLOADS" }
    GridLayout {
        Layout.fillWidth: true
        columns: form.width >= 700 ? 4 : 2
        columnSpacing: 16
        rowSpacing: 12
        Field { label: "Parallel downloads"; key: "concurrentDownloads"; numeric: true; placeholder: "6" }
        Field { label: "Parallel tasks"; key: "concurrentTasks"; numeric: true; placeholder: "10" }
        Field { label: "Retries"; key: "retries"; numeric: true; placeholder: "1" }
        Field { label: "Timeout (seconds)"; key: "timeout"; numeric: true; placeholder: "60" }
    }

    Heading { text: "SERVICES & API KEYS" }
    Hint { text: "Leave these empty to use Prism's defaults. Overrides are for mirrors, self-hosted metadata or your own API credentials." }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Field { label: "Metadata server"; key: "metaUrl"; placeholder: "https://meta.prismlauncher.org/" }
        Field { label: "Assets server"; key: "resourceUrl"; placeholder: "https://resources.download.minecraft.net/" }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        Field { label: "User agent"; key: "userAgent"; placeholder: "Prism default" }
        Field { label: "Microsoft client ID"; key: "msaClientId"; placeholder: "Prism default" }
    }
    RowLayout {
        Layout.fillWidth: true
        spacing: 16
        SecretField { label: "Modrinth token"; key: "modrinthToken"; hasKey: "hasModrinthToken"; clearKey: "clearModrinthToken" }
        SecretField { label: "CurseForge API key (Prism)"; key: "flameKey"; hasKey: "hasFlameKey"; clearKey: "clearFlameKey" }
    }
    Field { label: "Technic client ID"; key: "technicClientId"; placeholder: "Prism default" }
    RowLayout {
        Layout.fillWidth: true
        Layout.topMargin: 8
        Item { Layout.fillWidth: true }
        ActionButton { text: "Revert"; implicitWidth: 110; onClicked: form.service.load() }
        ActionButton { objectName: "saveNetwork"; text: "Save network settings"; primary: true; onClicked: form.save() }
    }
}
