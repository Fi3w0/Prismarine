import QtQuick

QtObject {
    required property var controller
    property var entries: []
    property bool backwards: false
    readonly property bool canGoBack: entries.length > 0
    function snapshot() {
        return { page: controller.page, instanceId: controller.details.instanceId, tab: controller.instanceTab };
    }
    function visit(page, id = "", tab = "overview") {
        const previous = snapshot();
        if (previous.page === page && (page !== "instance" || (previous.instanceId === id && previous.tab === tab))) return;
        entries = entries.concat([previous]).slice(-80);
        backwards = false;
        restore({page: page, instanceId: id, tab: tab});
    }
    function restore(route) {
        if (route.page === "instance") {
            controller.details.load(route.instanceId);
            controller.instanceTab = route.tab;
        }
        controller.page = route.page;
    }
    function back() {
        if (!entries.length) return;
        const route = entries[entries.length - 1];
        entries = entries.slice(0, -1);
        backwards = true;
        restore(route);
    }
}
