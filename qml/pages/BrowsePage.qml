import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Item {
    id: browse
    required property var controller
    property string targetId: controller.details.instanceId || controller.current.instanceId || ""
    property string contentType: "mod"
    property string world: ""
    property bool batchMode: false
    readonly property bool compactLayout: width < 1000 || height < 650
    readonly property bool compactProject: compactLayout && !!selectedProject.project_id
    readonly property var selection: controller.downloads.items(targetId, contentType)
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
        batchMode = selection.length > 0;
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
            visible: browse.width >= 1050 && !browse.compactProject
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
            spacing: 12
            Text {
                visible: !browse.compactProject
                text: ({mod: "Download mods", shader: "Download shaders", resourcepack: "Download resource packs", datapack: "Download datapacks", modpack: "Discover modpacks"})[browse.contentType]
                color: Colors.bone
                font.family: Colors.displayFont
                font.pixelSize: Typography.pageTitle
                font.letterSpacing: 2
            }
            BrowseTarget {
                visible: !browse.compactProject
                controller: browse.controller
                targetId: browse.targetId
                contentType: browse.contentType
                onTargetSelected: id => { browse.targetId = id; browse.performSearch(); }
            }
            RowLayout {
                visible: browse.contentType === "datapack" && !browse.compactProject
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
                visible: !browse.compactProject
                Layout.fillWidth: true
                SelectBox {
                    Layout.fillWidth: true
                    visible: browse.width < 1050
                    model: ["Mods", "Resource packs", "Shaders", "Datapacks", "Modpacks"]
                    currentIndex: ["mod", "resourcepack", "shader", "datapack", "modpack"].indexOf(browse.contentType)
                    onActivated: browse.chooseType(["mod", "resourcepack", "shader", "datapack", "modpack"][currentIndex])
                }
                SelectBox {
                    model: ["Modrinth", "CurseForge"]
                    currentIndex: browse.controller.catalog.provider === "curseforge" ? 1 : 0
                    onActivated: {
                        browse.controller.downloads.clear(browse.targetId, browse.contentType);
                        browse.controller.catalog.provider = currentIndex ? "curseforge" : "modrinth";
                        browse.categories = []; browse.performSearch();
                    }
                }
                Text { Layout.fillWidth: true; text: browse.packs ? "Each pack installs as a new instance" : ""; color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
                ActionButton {
                    visible: browse.controller.catalog.provider === "curseforge"
                    text: browse.controller.catalog.curseForgeReady ? "API key…" : "Add API key…"
                    onClicked: keyDialog.open()
                }
                ActionButton { visible: browse.packs; text: "Import archive…"; onClicked: browse.controller.importPack() }
            }
            RowLayout {
                visible: !browse.compactProject
                Layout.fillWidth: true
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
                ActionButton {
                    objectName: "browseBatchToggle"
                    visible: !browse.packs
                    implicitWidth: Math.max(144, contentItem.implicitWidth + 24)
                    text: browse.batchMode ? qsTr("Done selecting") : qsTr("Select multiple")
                    checkable: true
                    checked: browse.batchMode
                    onClicked: browse.batchMode = !browse.batchMode
                }
            }
            RowLayout {
                Layout.fillWidth: true
                Layout.fillHeight: true
                spacing: 14
                BrowseResults {
                    visible: !browse.compactProject
                    Layout.fillWidth: browse.compactLayout
                    controller: browse.controller
                    preferredPanelWidth: browse.width >= 1050 ? (browse.width - 266) * 0.45 : browse.width * 0.43
                    selectedProject: browse.selectedProject
                    targetId: browse.targetId
                    contentType: browse.contentType
                    activeCategories: browse.categories.length
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
                    visible: !browse.compactLayout || browse.compactProject
                    compact: browse.compactLayout
                    targetName: browse.targetInfo.name || ""
                    onDismissed: browse.selectedProject = ({})
                    world: browse.world
                    batchMode: browse.batchMode
                    controller: browse.controller
                    selectedProject: browse.selectedProject
                    targetId: browse.targetId
                    contentType: browse.contentType
                }
            }
            DownloadQueueBar {
                visible: !browse.packs && (browse.batchMode || browse.selection.length > 0)
                world: browse.world
                controller: browse.controller
                targetId: browse.targetId
                contentType: browse.contentType
                targetName: browse.targetInfo.name || ""
            }
        }
    }
}
