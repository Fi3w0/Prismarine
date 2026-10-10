import QtQuick
import QtQuick.Layouts

// The standard dialog button row: optional links on the left, Cancel and one
// primary action on the right. Use as a MotionDialog's footer.
Item {
    id: actions
    default property alias leading: leadingRow.data
    property string cancelText: "Cancel"
    property string confirmText: "OK"
    property string confirmName: ""
    property bool confirmEnabled: true
    property bool confirmVisible: true
    property bool cancelVisible: true
    property bool danger: false
    property int confirmWidth: 160
    signal cancelled
    signal confirmed
    implicitHeight: 72
    RowLayout {
        anchors { fill: parent; leftMargin: 24; rightMargin: 24; bottomMargin: 22; topMargin: 8 }
        spacing: 10
        RowLayout { id: leadingRow; spacing: 16 }
        Item { Layout.fillWidth: true }
        ActionButton {
            visible: actions.cancelVisible
            text: actions.cancelText
            implicitWidth: Math.max(110, contentItem.implicitWidth + 36)
            onClicked: actions.cancelled()
        }
        ActionButton {
            visible: actions.confirmVisible
            objectName: actions.confirmName
            text: actions.confirmText
            implicitWidth: Math.max(actions.confirmWidth, contentItem.implicitWidth + 36)
            primary: !actions.danger
            danger: actions.danger
            enabled: actions.confirmEnabled
            onClicked: actions.confirmed()
        }
    }
}
