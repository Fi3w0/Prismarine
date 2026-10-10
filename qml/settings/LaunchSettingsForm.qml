import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ColumnLayout {
    id: form
    required property var service
    property var javaManager: null
    property bool showSaveButton: true
    function save() {
        if (service.save(draft)) {
            saved();
            return true;
        }
        return false;
    }
    property var accounts: []
    property var draft: ({})
    property bool instanceMode: service.instanceId !== ""
    signal saved
    function reset() {
        draft = Object.assign({}, service.values);
    }
    function change(key, value) {
        let next = Object.assign({}, draft);
        next[key] = value;
        draft = next;
    }
    Component.onCompleted: reset()
    Connections {
        target: form.service
        function onChanged() {
            form.reset();
        }
    }
    spacing: 16
    Text {
        text: "GENERAL"
        color: Colors.brass
        font.family: Colors.displayFont
        font.letterSpacing: 2
        font.pixelSize: 13
    }
    InputField {
        Layout.fillWidth: true
        visible: form.instanceMode
        text: form.draft.name || ""
        placeholderText: "Instance name"
        onTextEdited: form.change("name", text)
    }
    Text {
        text: "Memory allocation"
        color: Colors.bone
        font.pixelSize: 17
    }
    ToggleSwitch {
        visible: form.instanceMode
        text: "Override launcher memory defaults"
        checked: !!form.draft.memoryOverride
        onToggled: form.change("memoryOverride", checked)
    }
    RowLayout {
        Layout.fillWidth: true
        Text {
            text: "Minimum (MiB)"
            color: Colors.subtext
            Layout.preferredWidth: 130
        }
        SpinBox {
            objectName: "minimumMemory"
            from: 256
            to: 262144
            stepSize: 256
            editable: true
            value: form.draft.minMemory || 512
            enabled: !form.instanceMode || !!form.draft.memoryOverride
            onValueModified: form.change("minMemory", value)
        }
        Text {
            text: "Maximum (MiB)"
            color: Colors.subtext
            Layout.leftMargin: 16
        }
        SpinBox {
            objectName: "maximumMemory"
            from: 256
            to: 262144
            stepSize: 256
            editable: true
            value: form.draft.maxMemory || 4096
            enabled: !form.instanceMode || !!form.draft.memoryOverride
            onValueModified: form.change("maxMemory", value)
        }
    }
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Colors.border
    }
    Text {
        text: "JAVA"
        color: Colors.brass
        font.family: Colors.displayFont
        font.letterSpacing: 2
        font.pixelSize: 13
    }
    ToggleSwitch {
        visible: !form.instanceMode; text: "Automatically select compatible Java in Prism"
        checked: !!form.draft.autoJava; onToggled: { form.change("autoJava", checked); if (checked) form.change("javaOverride", false); }
    }
    ToggleSwitch {
        visible: !form.instanceMode; text: "Download required Mojang Java at launch"
        enabled: !!form.draft.autoJava
        checked: !!form.draft.downloadJava; onToggled: form.change("downloadJava", checked)
    }
    ToggleSwitch {
        text: form.instanceMode ? "Use a custom Java executable" : "Use a custom Java executable instead of automatic selection"
        checked: !!form.draft.javaOverride
        onToggled: { form.change("javaOverride", checked); if (checked && !form.instanceMode) form.change("autoJava", false); }
    }
    InputField {
        Layout.fillWidth: true
        enabled: !!form.draft.javaOverride
        text: form.draft.javaPath || ""
        placeholderText: Qt.platform.os === "windows" ? "C:/Program Files/Java/bin/javaw.exe" : Qt.platform.os === "osx" ? "/Library/Java/JavaVirtualMachines/…/Contents/Home/bin/java" : "/usr/bin/java"
        onTextEdited: form.change("javaPath", text)
    }
    JavaRuntimePicker {
        Layout.fillWidth: true
        visible: !!form.javaManager
        manager: form.javaManager
        javaPath: form.draft.javaPath || ""
        arguments: form.draft.jvmArgs || ""
        minMemory: form.draft.minMemory || 512
        maxMemory: form.draft.maxMemory || 4096
        onSelected: path => { form.change("javaPath", path); form.change("javaOverride", true); if (!form.instanceMode) form.change("autoJava", false); }
    }
    ToggleSwitch {
        visible: form.instanceMode
        text: "Override JVM arguments"
        checked: !!form.draft.jvmOverride
        onToggled: form.change("jvmOverride", checked)
    }
    Text {
        text: "JVM arguments"
        color: Colors.subtext
        font.pixelSize: 13
    }
    InputField {
        Layout.fillWidth: true
        enabled: !form.instanceMode || !!form.draft.jvmOverride
        text: form.draft.jvmArgs || ""
        placeholderText: "Optional Java arguments"
        onTextEdited: form.change("jvmArgs", text)
    }
    Rectangle {
        Layout.fillWidth: true
        height: 1
        color: Colors.border
    }
    Text {
        text: "MINECRAFT"
        color: Colors.brass
        font.family: Colors.displayFont
        font.letterSpacing: 2
        font.pixelSize: 13
    }
    ToggleSwitch {
        visible: form.instanceMode
        text: "Override game window defaults"
        checked: !!form.draft.windowOverride
        onToggled: form.change("windowOverride", checked)
    }
    RowLayout {
        enabled: !form.instanceMode || !!form.draft.windowOverride
        Text {
            text: "Window size"
            color: Colors.subtext
            Layout.preferredWidth: 130
        }
        SpinBox {
            from: 320
            to: 16384
            editable: true
            value: form.draft.width || 854
            onValueModified: form.change("width", value)
        }
        Text {
            text: "×"
            color: Colors.subtext
        }
        SpinBox {
            from: 240
            to: 16384
            editable: true
            value: form.draft.height || 480
            onValueModified: form.change("height", value)
        }
    }
    ToggleSwitch {
        enabled: !form.instanceMode || !!form.draft.windowOverride
        text: "Start maximized"
        checked: !!form.draft.maximized
        onToggled: form.change("maximized", checked)
    }
    ToggleSwitch {
        visible: form.instanceMode
        text: "Join server on launch"
        checked: !!form.draft.joinServer
        onToggled: form.change("joinServer", checked)
    }
    InputField {
        visible: form.instanceMode && !!form.draft.joinServer
        Layout.fillWidth: true
        text: form.draft.server || ""
        placeholderText: "Server address"
        onTextEdited: form.change("server", text)
    }
    RowLayout {
        visible: form.instanceMode
        Layout.fillWidth: true
        Text {
            text: "Play as"
            color: Colors.subtext
            Layout.preferredWidth: 130
        }
        SelectBox {
            Layout.fillWidth: true
            model: [
                {
                    name: "Default account",
                    id: ""
                }
            ].concat(form.accounts)
            textRole: "name"
            currentIndex: Math.max(0, model.findIndex(a => a.id === (form.draft.accountId || "")))
            onActivated: form.change("accountId", model[currentIndex].id)
        }
    }
    Text {
        text: "PERFORMANCE"
        color: Colors.brass
        font.family: Colors.displayFont
        font.letterSpacing: 2
        font.pixelSize: 13
    }
    ToggleSwitch {
        visible: form.instanceMode
        text: "Override performance defaults"
        checked: !!form.draft.performanceOverride
        onToggled: form.change("performanceOverride", checked)
    }
    ToggleSwitch {
        enabled: !form.instanceMode || !!form.draft.performanceOverride
        text: "Enable GameMode"
        checked: !!form.draft.gameMode
        onToggled: form.change("gameMode", checked)
    }
    ToggleSwitch {
        enabled: !form.instanceMode || !!form.draft.performanceOverride
        text: "Enable MangoHud"
        checked: !!form.draft.mangoHud
        onToggled: form.change("mangoHud", checked)
    }
    Text { text: "CUSTOM COMMANDS"; color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: 13 }
    ToggleSwitch {
        visible: form.instanceMode
        text: "Override launcher commands"
        checked: !!form.draft.commandsOverride
        onToggled: form.change("commandsOverride", checked)
    }
    Text {
        Layout.fillWidth: true; wrapMode: Text.Wrap; color: Colors.subtext; font.pixelSize: 12
        text: "Prism runs these commands at launch and exit. Use $INST_MC_DIR for the game folder and $INST_JAVA for Java. Quote paths containing spaces."
    }
    Repeater {
        model: [{key: "PreLoadCommand", title: "Before loading the instance"}, {key: "PreLaunchCommand", title: "Before launching Minecraft"}, {key: "PostExitCommand", title: "After Minecraft exits"}, {key: "WrapperCommand", title: "Launch wrapper"}]
        delegate: ColumnLayout {
            required property var modelData
            Layout.fillWidth: true
            Text { text: modelData.title; color: Colors.subtext; font.pixelSize: 12 }
            InputField {
                Layout.fillWidth: true
                enabled: !form.instanceMode || !!form.draft.commandsOverride
                text: form.draft[modelData.key] || ""
                placeholderText: "Optional command"
                onTextEdited: form.change(modelData.key, text)
            }
        }
    }
    ActionButton {
        visible: form.showSaveButton
        objectName: "saveLaunchSettings"
        text: "Save settings"
        primary: true
        onClicked: form.save()
    }
}
