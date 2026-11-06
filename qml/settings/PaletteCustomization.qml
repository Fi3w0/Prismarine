import QtQuick
import QtQuick.Layouts

ColumnLayout {
    id: customization
    required property var preferences
    property string selectedRole: "accent"
    readonly property var selected: roles.find(role => role.key === selectedRole) || roles[0]
    readonly property var roles: [
        {key: "accent", label: qsTr("Accent"), hint: qsTr("Buttons, selection and highlights.")},
        {key: "base", label: qsTr("Window"), hint: qsTr("The background behind your pages.")},
        {key: "rail", label: qsTr("Navigation rail"), hint: qsTr("The strip holding Home, Library and Browse.")},
        {key: "mantle", label: qsTr("Sidebars"), hint: qsTr("Inset navigation and sidebar surfaces.")},
        {key: "surface", label: qsTr("Cards & dialogs"), hint: qsTr("Panels, dialogs and library detail cards.")},
        {key: "surfaceHi", label: qsTr("Fields & hover"), hint: qsTr("Text fields, hover and selected surfaces.")},
        {key: "rowAlt", label: qsTr("Alternate rows"), hint: qsTr("Alternating list rows.")},
        {key: "inset", label: qsTr("Inset panels"), hint: qsTr("Smaller panels inside cards.")},
        {key: "hero", label: qsTr("Hero banners"), hint: qsTr("Banner background when no custom image is shown.")},
        {key: "heroLine", label: qsTr("Banner lines"), hint: qsTr("The decorative sea lines on banners.")},
        {key: "text", label: qsTr("Main text"), hint: qsTr("Primary readable text.")},
        {key: "subtext", label: qsTr("Secondary text"), hint: qsTr("Hints, descriptions and metadata.")},
        {key: "bone", label: qsTr("Headings"), hint: qsTr("Prismarine's display headings.")},
        {key: "brass", label: qsTr("Brass details"), hint: qsTr("Section labels and decorative details.")},
        {key: "accentInk", label: qsTr("Button text"), hint: qsTr("Automatic for readability, or choose your own button text colour.")},
        {key: "border", label: qsTr("Separators"), hint: qsTr("Quiet borders and separators.")},
        {key: "outline", label: qsTr("Field outlines"), hint: qsTr("Visible borders around inputs and controls.")},
        {key: "success", label: qsTr("Success"), hint: qsTr("Ready, saved and connected states.")},
        {key: "warning", label: qsTr("Warnings"), hint: qsTr("Caution and low contrast.")},
        {key: "danger", label: qsTr("Errors"), hint: qsTr("Errors and destructive actions.")}
    ]
    Layout.fillWidth: true
    spacing: 18
    ColorPalette {
        id: preview
        systemMode: Colors.systemMode
        theme: customization.preferences.theme
        userAccent: customization.preferences.accentColor
        cornerStyle: customization.preferences.cornerStyle
        overrides: customization.preferences.paletteOverrides
    }
    PaletteStartingPoints { preferences: customization.preferences; previewColors: preview }
    GridLayout {
        Layout.fillWidth: true
        columns: width >= 900 ? 2 : 1
        columnSpacing: 18
        rowSpacing: 18
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 18
            ColourEditor {
                Layout.fillWidth: true
                preferences: customization.preferences
                previewColors: preview
                role: customization.selectedRole
                roleLabel: customization.selected.label
                roleHint: customization.selected.hint
                roles: customization.roles
                onRoleSelected: role => customization.selectedRole = role
            }
            PaletteSwatches {
                roles: customization.roles
                preferences: customization.preferences
                previewColors: preview
                selectedRole: customization.selectedRole
                onRoleSelected: role => customization.selectedRole = role
            }
        }
        ColumnLayout {
            Layout.fillWidth: true
            Layout.preferredWidth: 1
            Layout.alignment: Qt.AlignTop
            spacing: 18
            SettingsLivePreview { previewColors: preview; preferences: customization.preferences }
            ContrastPanel { previewColors: preview }
            Rectangle {
                Layout.fillWidth: true
                implicitHeight: shape.implicitHeight + 36
                radius: 20
                color: Colors.surface
                border.color: Colors.border
                ColumnLayout {
                    id: shape
                    anchors { left: parent.left; right: parent.right; top: parent.top; margins: 18 }
                    spacing: 14
                    Text { text: qsTr("Shape & surfaces"); color: Colors.brass; font.family: Colors.displayFont; font.pixelSize: Typography.body; font.letterSpacing: 2 }
            SettingsChoiceRow {
                objectName: "cornerStyle"
                title: qsTr("Corners")
                detail: qsTr("The shape of buttons, fields and cover artwork.")
                choices: [{label: qsTr("Rounded"), value: "rounded"}, {label: qsTr("Angular"), value: "angular"}]
                value: customization.preferences.cornerStyle
                onChosen: value => customization.preferences.cornerStyle = value
            }
                }
            }
            SettingsLayoutPreview { preferences: customization.preferences }
            Text { Layout.fillWidth: true; text: qsTr("Deep sea and Light keep separate colours. Use the colour tiles to select a role; Reset this colour restores only that role."); color: Colors.subtext; font.pixelSize: Typography.bodySmall; wrapMode: Text.Wrap }
        }
    }
}
