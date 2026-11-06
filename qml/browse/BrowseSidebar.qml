import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: sidebar
    required property var controller
    required property string targetId
    required property string contentType
    required property var categories
    signal categoriesSelected(var categories)
    readonly property var target: controller.instances.getById(targetId)
    signal targetSelected(string id)
    signal typeSelected(string type)
    Layout.preferredWidth: 218
    Layout.fillHeight: true
    color: Colors.mantle
    Rectangle {
        anchors.right: parent.right
        width: 1
        height: parent.height
        color: Colors.border
    }
    ColumnLayout {
        anchors {
            fill: parent
            margins: 16
        }
        spacing: 16
        Text {
            text: "CONTENT"
            font.family: Colors.displayFont
            font.pixelSize: Typography.bodySmall
            font.letterSpacing: 2
            color: Colors.brass
        }
        Repeater {
            model: [
                {title: "Modpacks", key: "modpack"},
                {title: "Datapacks", key: "datapack"},
                {
                    title: "Mods",
                    key: "mod"
                },
                {
                    title: "Resource packs",
                    key: "resourcepack"
                },
                {
                    title: "Shaders",
                    key: "shader"
                }
            ]
            delegate: SideNavItem {
                required property var modelData
                Layout.topMargin: -12
                text: modelData.title
                checked: sidebar.contentType === modelData.key
                onClicked: sidebar.typeSelected(modelData.key)
            }
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Text {
                Layout.fillWidth: true
                text: "CATEGORIES"
                font.family: Colors.displayFont
                font.pixelSize: Typography.bodySmall
                font.letterSpacing: 2
                color: Colors.brass
            }
            TextLink {
                text: "Reset"
                underline: false
                visible: sidebar.categories.length > 0
                onClicked: sidebar.categoriesSelected([])
            }
        }
        Text {
            Layout.fillWidth: true
            Layout.topMargin: -12
            visible: sidebar.categories.length > 1
            text: qsTr("Showing projects in all %1 categories").arg(sidebar.categories.length)
            color: Colors.subtext
            font.pixelSize: Typography.caption
            wrapMode: Text.Wrap
        }
        ListView {
            id: categoryList
            Layout.fillWidth: true
            Layout.fillHeight: true
            Layout.topMargin: -10
            clip: true
            spacing: 1
            boundsBehavior: Flickable.StopAtBounds
            ScrollBar.vertical: ScrollBar {}
            model: {
                sidebar.controller.catalog.categoryTags; // re-evaluate when tags arrive
                return sidebar.controller.catalog.categoriesFor(sidebar.contentType);
            }
            delegate: SideNavItem {
                required property string modelData
                width: ListView.view.width
                implicitHeight: 28
                text: modelData.charAt(0).toUpperCase() + modelData.slice(1).replace(/-/g, " ")
                checked: sidebar.categories.indexOf(modelData) >= 0
                onClicked: sidebar.categoriesSelected(checked ? sidebar.categories.filter(it => it !== modelData) : sidebar.categories.concat([modelData]))
            }
            Text {
                anchors.centerIn: parent
                visible: !categoryList.count
                text: sidebar.controller.catalog.provider === "curseforge" ? "Use search to find CurseForge content." : "Categories load from Modrinth."
                color: Colors.subtext
                font.pixelSize: Typography.caption
            }
        }
        ActionButton {
            Layout.fillWidth: true
            text: "←  Instance"
            visible: sidebar.contentType !== "modpack"
            enabled: !!sidebar.targetId
            onClicked: sidebar.controller.openInstance(sidebar.targetId, sidebar.contentType === "mod" ? "mods" : sidebar.contentType === "shader" ? "shaders" : "resourcepacks")
        }
    }
}
