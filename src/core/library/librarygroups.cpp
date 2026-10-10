#include "instancemodel.h"
#include "../prism/paths.h"
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>

// Prism stores groups in <instances>/instgroups.json:
// {"formatVersion":"1","groups":{"Name":{"hidden":false,"instances":["folder id"]}}}
// Prism reads this file at startup and writes it whenever groups change in its own window.
static QJsonObject readGroupFile(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    return QJsonDocument::fromJson(file.readAll()).object();
}

QVariantList InstanceModel::groups() const
{
    const QJsonObject definitions = readGroupFile(m_instanceDir + "/instgroups.json").value("groups").toObject();
    QVariantList result; QSet<QString> grouped;
    for (auto it = definitions.begin(); it != definitions.end(); ++it) {
        QVariantList members;
        bool onlyCopies = false;
        for (const auto &id : it.value().toObject().value("instances").toArray()) {
            const auto instance = getById(id.toString());
            if (!instance.value("altOf").toString().isEmpty()) { onlyCopies = true; continue; }
            if (instance.isEmpty() || grouped.contains(id.toString())) continue;
            members.append(instance); grouped.insert(id.toString());
        }
        // A group holding only multi-account copies is Prism-side bookkeeping.
        if (members.isEmpty() && onlyCopies) continue;
        // Empty groups stay visible so new groups can receive instances.
        result.append(QVariantMap{{"name", it.key()}, {"instances", members}, {"collapsed", it.value().toObject().value("hidden").toBool()}, {"editable", true}});
    }
    QVariantList ungrouped;
    for (const auto &instance : m_all) if (!grouped.contains(instance.id) && instance.altOf.isEmpty()) ungrouped.append(getById(instance.id));
    if (!ungrouped.isEmpty() || !definitions.isEmpty())
        result.append(QVariantMap{{"name", definitions.isEmpty() ? "Your instances" : "Ungrouped"}, {"instances", ungrouped}, {"collapsed", false}, {"editable", false}});
    return result;
}

QStringList InstanceModel::groupNames() const
{
    return readGroupFile(m_instanceDir + "/instgroups.json").value("groups").toObject().keys();
}

QString InstanceModel::groupOf(const QString &instanceId) const
{
    const QJsonObject definitions = readGroupFile(m_instanceDir + "/instgroups.json").value("groups").toObject();
    for (auto it = definitions.begin(); it != definitions.end(); ++it)
        if (it.value().toObject().value("instances").toArray().contains(instanceId)) return it.key();
    return {};
}

bool InstanceModel::prismRunning() const
{
    return Prism::launcherRunning();
}

// Applies one change to the group file, keeping fields Prism may add later.
bool InstanceModel::editGroups(const std::function<QString(QJsonObject &)> &change)
{
    const QString path = m_instanceDir + "/instgroups.json";
    QJsonObject root = readGroupFile(path);
    if (QFile::exists(path) && root.isEmpty() && QFileInfo(path).size() > 0) {
        emit errorOccurred("Prism's group file could not be read, so it was left unchanged.");
        return false;
    }
    QJsonObject groups = root.value("groups").toObject();
    if (const QString error = change(groups); !error.isEmpty()) {
        emit errorOccurred(error);
        return false;
    }
    root.insert("groups", groups);
    if (!root.contains("formatVersion")) root.insert("formatVersion", "1");
    QSaveFile output(path);
    if (!output.open(QIODevice::WriteOnly) || output.write(QJsonDocument(root).toJson()) < 0 || !output.commit()) {
        emit errorOccurred("Could not save the instance groups.");
        return false;
    }
    reload();
    return true;
}

static QString checkGroupName(const QString &name, const QJsonObject &groups, const QString &except = {})
{
    if (name.isEmpty() || name.size() > 80 || name.contains(QRegularExpression("[\\x{0000}-\\x{001f}\\x{007f}]")))
        return "Enter a group name on a single line.";
    for (const auto &existing : groups.keys())
        if (existing != except && existing.compare(name, Qt::CaseInsensitive) == 0) return "A group with this name already exists.";
    return {};
}

bool InstanceModel::createGroup(const QString &name)
{
    const QString trimmed = name.trimmed();
    return editGroups([&](QJsonObject &groups) {
        if (const QString error = checkGroupName(trimmed, groups); !error.isEmpty()) return error;
        groups.insert(trimmed, QJsonObject{{"hidden", false}, {"instances", QJsonArray()}});
        return QString();
    });
}

bool InstanceModel::renameGroup(const QString &name, const QString &newName)
{
    const QString trimmed = newName.trimmed();
    if (trimmed == name) return true;
    return editGroups([&](QJsonObject &groups) {
        if (!groups.contains(name)) return QStringLiteral("This group no longer exists.");
        if (const QString error = checkGroupName(trimmed, groups, name); !error.isEmpty()) return error;
        const QJsonValue value = groups.take(name);
        groups.insert(trimmed, value);
        return QString();
    });
}

bool InstanceModel::deleteGroup(const QString &name)
{
    // Instances in a deleted group become ungrouped; nothing on disk besides the group file changes.
    return editGroups([&](QJsonObject &groups) {
        if (!groups.contains(name)) return QStringLiteral("This group no longer exists.");
        groups.remove(name);
        return QString();
    });
}

bool InstanceModel::moveToGroup(const QString &instanceId, const QString &group)
{
    if (!find(instanceId)) { emit errorOccurred("This instance is no longer available."); return false; }
    return editGroups([&](QJsonObject &groups) {
        if (!group.isEmpty() && !groups.contains(group)) return QStringLiteral("This group no longer exists.");
        for (const auto &key : groups.keys()) {
            QJsonObject definition = groups.value(key).toObject();
            QJsonArray members = definition.value("instances").toArray();
            for (int i = members.size() - 1; i >= 0; --i)
                if (members.at(i).toString() == instanceId) members.removeAt(i);
            if (key == group) members.append(instanceId);
            definition.insert("instances", members);
            groups.insert(key, definition);
        }
        return QString();
    });
}

bool InstanceModel::setGroupCollapsed(const QString &name, bool collapsed)
{
    return editGroups([&](QJsonObject &groups) {
        if (!groups.contains(name)) return QStringLiteral("This group no longer exists.");
        QJsonObject definition = groups.value(name).toObject();
        definition.insert("hidden", collapsed);
        groups.insert(name, definition);
        return QString();
    });
}

bool InstanceModel::moveToGroupQuietly(const QString &instanceId, const QString &group)
{
    return editGroups([&](QJsonObject &groups) {
        if (!groups.contains(group)) groups.insert(group, QJsonObject{{"hidden", false}, {"instances", QJsonArray()}});
        for (const auto &key : groups.keys()) {
            QJsonObject definition = groups.value(key).toObject();
            QJsonArray members = definition.value("instances").toArray();
            for (int i = members.size() - 1; i >= 0; --i)
                if (members.at(i).toString() == instanceId) members.removeAt(i);
            if (key == group) members.append(instanceId);
            definition.insert("instances", members);
            groups.insert(key, definition);
        }
        return QString();
    });
}
