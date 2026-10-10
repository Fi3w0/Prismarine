import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: project
    required property var controller
    property var selectedProject: ({})
    property string world: ""
    property string targetId: ""
    property string contentType: "mod"
    property int selectedTab: 0
    readonly property var selectedVersion: controller.catalog.versions[versionPicker.currentIndex] || ({})
    readonly property bool restricted: selectedVersion.provider === "curseforge" && !(selectedVersion.files || []).some(file => !!file.url)
    readonly property bool chosen: controller.downloads.contains(targetId, contentType, selectedProject.project_id || "")
    onSelectedProjectChanged: { selectedTab = 0; versionPicker.currentIndex = 0; }
    Layout.fillWidth: true
    Layout.minimumWidth: 300
    Layout.fillHeight: true
    radius: 14
    color: Colors.surface
    border.color: Colors.border
    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 16
        spacing: 12
        RowLayout {
            Layout.fillWidth: true
            spacing: 14
            ContentIcon { size: 52; source: project.selectedProject.icon_url || "" }
            ColumnLayout {
                Layout.fillWidth: true
                spacing: 5
                Text { Layout.fillWidth: true; text: project.selectedProject.title || "Find your next addition"; color: Colors.bone; font.family: Colors.displayFont; font.pixelSize: 24; elide: Text.ElideRight }
                Text { Layout.fillWidth: true; text: project.selectedProject.author ? "by " + project.selectedProject.author : "Choose a project to explore"; color: Colors.subtext; font.pixelSize: 12; elide: Text.ElideRight }
            }
            NavButton { visible: !!project.selectedProject.project_id; iconName: "external"; hint: "Open project website"; onClicked: Qt.openUrlExternally(project.selectedProject.website || ("https://modrinth.com/" + (project.contentType === "datapack" ? "datapack" : project.contentType) + "/" + project.selectedProject.slug)) }
        }
        RowLayout {
            Layout.fillWidth: true
            visible: !!project.selectedProject.project_id
            spacing: 2
            Repeater {
                model: ["Description", "Versions", "Gallery", "Dependencies"]
                delegate: Button {
                    id: tab
                    required property string modelData
                    required property int index
                    Layout.fillWidth: true
                    implicitHeight: 36
                    onClicked: project.selectedTab = index
                    contentItem: Text { text: tab.modelData; color: project.selectedTab === tab.index ? Colors.bone : Colors.subtext; font.family: Colors.displayFont; font.pixelSize: 12; horizontalAlignment: Text.AlignHCenter; verticalAlignment: Text.AlignVCenter; elide: Text.ElideRight }
                    background: Rectangle { color: "transparent"; Rectangle { anchors.bottom: parent.bottom; width: parent.width; height: 2; color: project.selectedTab === tab.index ? Colors.accent : "transparent"; Behavior on color { ColorAnimation { duration: Colors.animations ? 200 : 0 } } } }
                }
            }
        }
        ProjectContent {
            Layout.fillWidth: true
            Layout.fillHeight: true
            controller: project.controller
            selectedProject: project.selectedProject
            selectedVersion: project.selectedVersion
            selectedTab: project.selectedTab
            onVersionSelected: index => versionPicker.currentIndex = index
        }
        Rectangle { Layout.fillWidth: true; implicitHeight: 1; color: Colors.border }
        Text {
            Layout.fillWidth: true
            text: project.restricted ? "The author requires a website download. Open the project website, then import the downloaded file." : controller.catalog.error || (controller.catalog.versionsLoading ? "Finding compatible versions…" : !controller.catalog.versions.length && project.selectedProject.project_id ? "No compatible versions for this instance." : (project.contentType === "modpack" ? "Choose a pack release · creates a new instance" : "Version · compatible with your instance"))
            color: controller.catalog.error ? Colors.danger : Colors.subtext
            font.pixelSize: 11
            wrapMode: Text.Wrap
        }
        RowLayout {
            Layout.fillWidth: true
            SelectBox {
                id: versionPicker
                objectName: "downloadVersionPicker"
                Layout.fillWidth: true
                Layout.minimumWidth: 0
                model: controller.catalog.versions
                textRole: "name"
                enabled: model.length > 0 && !controller.catalog.versionsLoading
            }
            ActionButton {
                objectName: "selectDownloadButton"
                implicitWidth: Math.max(120, contentItem.implicitWidth + 40)
                Layout.minimumWidth: implicitWidth
                text: project.contentType === "modpack" ? (project.selectedVersion.provider === "curseforge" ? "Import in Prism" : "Install pack") : project.chosen ? "Selected ✓" : "Select"
                primary: !project.chosen
                enabled: !project.restricted && !!project.selectedVersion.id && !controller.catalog.versionsLoading && (project.contentType === "modpack" || (!!project.targetId && (project.contentType !== "datapack" || !!project.world)))
                onClicked: {
                    if (project.contentType === "modpack") { controller.installPackVersion(project.selectedVersion); return; }
                    if (project.chosen) controller.downloads.remove(project.targetId, project.contentType, project.selectedProject.project_id);
                    else controller.downloads.add(project.targetId, project.contentType, project.selectedProject, project.selectedVersion);
                }
            }
        }
    }
}
