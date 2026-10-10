import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

ScrollView {
    id: content
    objectName: "projectContentScroll"
    required property var controller
    required property var selectedProject
    required property var selectedVersion
    property int selectedTab: 0
    signal versionSelected(int index)
    clip: true
    contentWidth: availableWidth
    onSelectedTabChanged: if (contentItem) contentItem.contentY = 0
    onSelectedProjectChanged: if (contentItem) contentItem.contentY = 0
    ColumnLayout {
        width: content.availableWidth
        spacing: 14
        Text {
            Layout.fillWidth: true
            visible: content.selectedTab === 0
            text: content.controller.catalog.project.body || content.selectedProject.description || "Select projects, choose versions, then review your selection together."
            color: Colors.subtext
            font.pixelSize: 14
            wrapMode: Text.Wrap
            textFormat: content.controller.catalog.project.plainText ? Text.PlainText : Text.MarkdownText
            lineHeight: 1.4
            onLinkActivated: link => Qt.openUrlExternally(link)
        }
        Repeater {
            model: content.selectedTab === 1 ? content.controller.catalog.versions : []
            delegate: ItemDelegate {
                required property var modelData
                required property int index
                Layout.fillWidth: true
                implicitHeight: 62
                onClicked: content.versionSelected(index)
                background: Rectangle { radius: 8; color: parent.hovered || content.selectedVersion.id === parent.modelData.id ? Colors.surfaceHi : "transparent" }
                contentItem: Column {
                    spacing: 5
                    Text { width: parent.width; text: modelData.name; color: Colors.text; font.pixelSize: 14; elide: Text.ElideRight }
                    Text { text: modelData.version_type + " · " + (modelData.date_published || "").slice(0, 10); color: Colors.subtext; font.pixelSize: 11 }
                }
            }
        }
        Repeater {
            model: content.selectedTab === 2 ? (content.controller.catalog.project.gallery || []) : []
            delegate: ColumnLayout {
                required property var modelData
                Layout.fillWidth: true
                Image { Layout.fillWidth: true; Layout.preferredHeight: width * 0.57; source: modelData.url; fillMode: Image.PreserveAspectFit; asynchronous: true }
                Text { Layout.fillWidth: true; text: modelData.title || modelData.description || ""; color: Colors.subtext; font.pixelSize: 12; wrapMode: Text.Wrap }
            }
        }
        Text {
            Layout.fillWidth: true
            visible: content.selectedTab === 2 && !(content.controller.catalog.project.gallery || []).length
            text: "This project has no gallery images."
            color: Colors.subtext
            font.pixelSize: 14
        }
        Repeater {
            model: content.selectedTab === 3 ? (content.selectedVersion.dependencies || []) : []
            delegate: Text {
                required property var modelData
                Layout.fillWidth: true
                text: modelData.dependency_type + " · " + (modelData.file_name || modelData.project_id || modelData.version_id)
                color: Colors.text
                font.pixelSize: 14
                wrapMode: Text.Wrap
            }
        }
        Text {
            Layout.fillWidth: true
            visible: content.selectedTab === 3
            text: (content.selectedVersion.dependencies || []).length ? "Required dependencies are resolved and included when you review your selection." : "No dependencies declared for this version."
            color: Colors.subtext
            font.pixelSize: 13
            wrapMode: Text.Wrap
        }
    }
}
