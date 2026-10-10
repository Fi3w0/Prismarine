import QtQuick

QtObject {
    property var entries: []
    function items(target, type) { return entries.filter(it => it.target === target && it.type === type); }
    function contains(target, type, project) { return items(target, type).some(it => it.project.project_id === project); }
    function add(target, type, project, version) {
        remove(target, type, project.project_id);
        entries = entries.concat([{target: target, type: type, project: project, version: version}]);
    }
    function remove(target, type, project) { entries = entries.filter(it => !(it.target === target && it.type === type && it.project.project_id === project)); }
    function clear(target, type) { entries = entries.filter(it => !(it.target === target && it.type === type)); }
}
