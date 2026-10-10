import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: browse
    required property var controller
    property string targetId: controller.details.instanceId || controller.current.instanceId || ""
    property string contentType: "mod"
    property string world: ""
    onTargetIdChanged: {
        world = "";
        controller.downloads.clear(targetId, "datapack");
    }
    readonly property var worlds: controller.instances.worlds.filter(it => it.instanceId === targetId)
    readonly property bool packs: contentType === "modpack"
    function chooseType(type) { contentType = type; categories = []; performSearch(); }
    property var selectedProject: ({})
    property var categories: []
    objectName: "browsePage"
    readonly property var targetInfo: controller.instances.getById(targetId)
    function performSearch() {
        selectedProject = ({});
        controller.catalog.search(query.text, packs ? "" : targetInfo.version || "", packs ? "" : targetInfo.loader || "", contentType, categories);
    }
    Component.onCompleted: {
        contentType = controller.pendingBrowseType || "mod"; world = controller.pendingBrowseWorld || "";
        controller.pendingBrowseType = ""; controller.pendingBrowseWorld = "";
        if (controller.pendingBrowseQuery) {
            query.text = controller.pendingBrowseQuery;
            controller.pendingBrowseQuery = "";
        }
        controller.catalog.loadCategories();
        performSearch();
    }
    CurseForgeKeyDialog { id: keyDialog; catalog: browse.controller.catalog; anchors.centerIn: Overlay.overlay; onAccepted: browse.performSearch() }
    Connections {
        target: browse.controller.catalog
        function onCredentialsChanged() { if (browse.controller.catalog.provider === "curseforge") browse.performSearch(); }
    }
    Timer {
        id: searchDelay
        interval: 400
        onTriggered: browse.performSearch()
    }
    RowLayout {
        anchors.fill: parent
        spacing: 0
        BrowseSidebar {
            controller: browse.controller
            targetId: browse.targetId
            contentType: browse.contentType
            categories: browse.categories
            visible: browse.width >= 1050
            onCategoriesSelected: chosen => {
                browse.categories = chosen;
                browse.performSearch();
            }
            onTargetSelected: id => {
                browse.targetId = id;
                browse.performSearch();
            }
            onTypeSelected: type => {
                browse.contentType = type;
                browse.categories = [];
                browse.performSearch();
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.margins: 24
            spacing: 16
            Text {
                text: ({mod: "Download mods", shader: "Download shaders", resourcepack: "Download resource packs", datapack: "Download datapacks", modpack: "Discover modpacks"})[browse.contentType]
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: 30
                font.letterSpacing: 2
            }
            RowLayout {
                Layout.fillWidth: true
                visible: browse.width < 1050
                SelectBox {
                    Layout.fillWidth: true
                    visible: !browse.packs
                    model: browse.controller.instances.allInstances
                    textRole: "name"
                    currentIndex: Math.max(0, model.findIndex(it => it.instanceId === browse.targetId))
                    onActivated: {
                        browse.targetId = model[currentIndex].instanceId;
                        browse.performSearch();
                    }
                }
                SelectBox {
                    model: ["Mods", "Resource packs", "Shaders", "Datapacks", "Modpacks"]
                    currentIndex: ["mod", "resourcepack", "shader", "datapack", "modpack"].indexOf(browse.contentType)
                    onActivated: {
                        browse.contentType = ["mod", "resourcepack", "shader", "datapack", "modpack"][currentIndex];
                        browse.performSearch();
                    }
                }
            }
            RowLayout {
                visible: browse.contentType === "datapack"
                Layout.fillWidth: true
                Text { text: "Install into world"; color: Colors.subtext }
                SelectBox {
                    Layout.fillWidth: true; model: browse.worlds; textRole: "name"
                    currentIndex: model.findIndex(it => it.name === browse.world)
                    onActivated: { browse.controller.downloads.clear(browse.targetId, "datapack"); browse.world = model[currentIndex].name; }
                }
                Text { visible: !browse.worlds.length; text: "Create a world in Minecraft first."; color: Colors.subtext }
            }
            RowLayout {
                Layout.fillWidth: true
                SelectBox {
                    model: ["Modrinth", "CurseForge"]
                    currentIndex: browse.controller.catalog.provider === "curseforge" ? 1 : 0
                    onActivated: {
                        browse.controller.downloads.clear(browse.targetId, browse.contentType);
                        browse.controller.catalog.provider = currentIndex ? "curseforge" : "modrinth";
                        browse.categories = []; browse.performSearch();
                    }
                }
                Text { Layout.fillWidth: true; text: browse.packs ? "Each pack installs as a new instance" : ""; color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.Wrap }
                ActionButton {
                    visible: browse.controller.catalog.provider === "curseforge"
                    text: browse.controller.catalog.curseForgeReady ? "API key…" : "Add API key…"
                    onClicked: keyDialog.open()
                }
                ActionButton { visible: browse.packs; text: "Import archive…"; onClicked: browse.controller.importPack() }
            }
            InputField {
                id: query
                Layout.fillWidth: true
                placeholderText: browse.controller.catalog.provider === "curseforge" ? "Search CurseForge…" : "Search Modrinth…"
                onTextChanged: searchDelay.restart()
                onAccepted: {
                    searchDelay.stop();
                    browse.performSearch();
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14
                BrowseResults {
                    controller: browse.controller
                    preferredPanelWidth: browse.width >= 1050 ? (browse.width - 266) * 0.45 : browse.width * 0.43
                    selectedProject: browse.selectedProject
                    targetId: browse.targetId
                    contentType: browse.contentType
                    onApiKeyRequested: keyDialog.open()
                    onPrismInstallRequested: {
                        if (browse.packs) browse.controller.instances.openPrism();
                        else browse.controller.instances.editInPrism(browse.targetId);
                    }
                    onProjectSelected: project => {
                        browse.selectedProject = project;
                        controller.catalog.loadVersions(project.project_id, browse.packs ? "" : browse.targetInfo.version || "", browse.contentType === "mod" ? browse.targetInfo.loader || "" : browse.contentType === "datapack" ? "datapack" : "");
                        controller.catalog.loadProject(project.project_id);
                    }
                }
                BrowseProject {
                    world: browse.world
                    controller: browse.controller
                    selectedProject: browse.selectedProject
                    targetId: browse.targetId
                    contentType: browse.contentType
                }
            }
            DownloadQueueBar {
                visible: !browse.packs
                world: browse.world
                controller: browse.controller
                targetId: browse.targetId
                contentType: browse.contentType
            }
        }
    }
}
