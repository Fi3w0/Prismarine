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
        SelectBox {
            Layout.fillWidth: true
            model: sidebar.controller.instances.allInstances
            visible: sidebar.contentType !== "modpack"
            textRole: "name"
            currentIndex: Math.max(0, model.findIndex(it => it.instanceId === sidebar.targetId))
            onActivated: sidebar.targetSelected(model[currentIndex].instanceId)
        }
        Chip {
            text: sidebar.controller.catalog.provider === "curseforge" ? "CurseForge" : "Modrinth"
            tint: Colors.accent
            active: true
            Layout.fillWidth: true
        }
        Text {
            text: "CONTENT"
            font.family: Colors.displayFont
            font.pixelSize: 12
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
        Text {
            text: "COMPATIBILITY"
            font.family: Colors.displayFont
            font.pixelSize: 12
            font.letterSpacing: 2
            color: Colors.brass
            Layout.topMargin: 10
        }
        Text {
            text: "Game version"
            color: Colors.subtext
            font.pixelSize: 12
        }
        InputField {
            Layout.fillWidth: true
            readOnly: true
            text: sidebar.contentType === "modpack" ? "All versions" : sidebar.target.version || "Select an instance"
        }
        Text {
            text: "Loader"
            color: Colors.subtext
            font.pixelSize: 12
            visible: sidebar.contentType === "mod"
        }
        InputField {
            Layout.fillWidth: true
            readOnly: true
            visible: sidebar.contentType === "mod"
            text: sidebar.target.loader || "—"
        }
        RowLayout {
            Layout.fillWidth: true
            Layout.topMargin: 6
            Text {
                Layout.fillWidth: true
                text: "CATEGORIES"
                font.family: Colors.displayFont
                font.pixelSize: 12
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
                font.pixelSize: 11
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
