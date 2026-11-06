pragma Singleton
import QtQuick

QtObject {
    // Logical pixels: 15 px body text, with smaller roles for dense metadata.
    // Display roles retain Marcellus SC at the call site.
    readonly property int micro: 11
    readonly property int chartLabel: 11
    readonly property int badge: 11
    readonly property int caption: 12
    readonly property int bodySmall: 13
    readonly property int body: 15
    readonly property int control: 15
    readonly property int bodyLarge: 16
    readonly property int subtitle: 18
    readonly property int valueSmall: 18
    readonly property int titleSmall: 18
    readonly property int cardTitle: 20
    readonly property int sectionTitle: 20
    readonly property int panelTitle: 24
    readonly property int statistic: 24
    readonly property int emptyTitle: 24
    readonly property int dialogTitle: 28
    readonly property int detailTitle: 28
    readonly property int contentTitle: 28
    readonly property int pageTitle: 30
    readonly property int heroCompact: 32
    readonly property int storageTotal: 36
    readonly property int brand: 36
    readonly property int hero: 44
    readonly property int welcomeCompact: 48
    readonly property int welcome: 60
}
