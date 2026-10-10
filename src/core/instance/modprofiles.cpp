#include "instancedetails.h"
#include <QDateTime>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>

// Mod profiles remember which mods are on or off, by filename without ".disabled".
// They live beside the instance (".prismarine-profiles.json"), which loaders never read.
namespace {
QString baseName(const QString &fileName)
{
    return fileName.endsWith(".disabled") ? fileName.left(fileName.size() - 9) : fileName;
}
QStringList strings(const QJsonValue &value)
{
    QStringList out;
    for (const auto &item : value.toArray()) out << item.toString();
    return out;
}
}

QString InstanceDetails::profileFile() const
{
    const QString path = m_model->instancePath(m_id);
    return path.isEmpty() ? QString() : path + "/.prismarine-profiles.json";
}

QVariantList InstanceDetails::profiles() const
{
    QFile file(profileFile());
    if (!file.open(QIODevice::ReadOnly)) return {};
    QSet<QString> enabled, disabled;
    for (const auto &value : m_contents.mods) {
        const auto mod = value.toMap();
        (mod.value("enabled").toBool() ? enabled : disabled).insert(baseName(mod.value("fileName").toString()));
    }
    QVariantList result;
    for (const auto &value : QJsonDocument::fromJson(file.readAll()).object().value("profiles").toArray()) {
        const auto profile = value.toObject();
        const QStringList on = strings(profile.value("enabled")), off = strings(profile.value("disabled"));
        // A profile is current when every mod it names is in the state it records.
        bool current = !on.isEmpty() || !off.isEmpty();
        int missing = 0;
        for (const auto &name : on) { if (!enabled.contains(name)) { current = false; if (!disabled.contains(name)) ++missing; } }
        for (const auto &name : off) { if (!disabled.contains(name)) { current = false; if (!enabled.contains(name)) ++missing; } }
        result.append(QVariantMap{{"name", profile.value("name").toString()}, {"enabledCount", on.size()}, {"disabledCount", off.size()},
            {"missing", missing}, {"current", current}, {"saved", profile.value("saved").toString()}});
    }
    return result;
}

bool InstanceDetails::writeProfiles(const std::function<QString(QJsonArray &)> &change)
{
    const QString path = profileFile();
    if (path.isEmpty() || m_loading) return false;
    QJsonObject root;
    if (QFile file(path); file.open(QIODevice::ReadOnly)) {
        const auto document = QJsonDocument::fromJson(file.readAll());
        if (!document.isObject() && file.size() > 0) { emit errorOccurred("The saved profiles could not be read, so they were left unchanged."); return false; }
        root = document.object();
    }
    QJsonArray list = root.value("profiles").toArray();
    if (const QString error = change(list); !error.isEmpty()) { emit errorOccurred(error); return false; }
    root.insert("profiles", list);
    QSaveFile output(path);
    if (!output.open(QIODevice::WriteOnly) || output.write(QJsonDocument(root).toJson()) < 0 || !output.commit()) {
        emit errorOccurred("Could not save mod profiles.");
        return false;
    }
    emit changed();
    return true;
}

bool InstanceDetails::saveProfile(const QString &name)
{
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || trimmed.size() > 60 || trimmed.contains(QRegularExpression("[\\x{0000}-\\x{001f}]"))) {
        emit errorOccurred("Enter a profile name on a single line.");
        return false;
    }
    QJsonArray on, off;
    for (const auto &value : m_contents.mods) {
        const auto mod = value.toMap();
        (mod.value("enabled").toBool() ? on : off).append(baseName(mod.value("fileName").toString()));
    }
    // Saving under an existing name replaces that profile.
    return writeProfiles([&](QJsonArray &list) {
        for (int i = list.size() - 1; i >= 0; --i)
            if (list.at(i).toObject().value("name").toString().compare(trimmed, Qt::CaseInsensitive) == 0) list.removeAt(i);
        list.append(QJsonObject{{"name", trimmed}, {"enabled", on}, {"disabled", off}, {"saved", QDateTime::currentDateTime().toString(Qt::ISODate)}});
        return QString();
    });
}

bool InstanceDetails::deleteProfile(const QString &name)
{
    return writeProfiles([&](QJsonArray &list) {
        for (int i = list.size() - 1; i >= 0; --i)
            if (list.at(i).toObject().value("name").toString() == name) { list.removeAt(i); return QString(); }
        return QStringLiteral("This profile no longer exists.");
    });
}

int InstanceDetails::applyProfile(const QString &name)
{
    if (m_loading) return -1;
    QFile file(profileFile());
    QJsonObject profile;
    if (file.open(QIODevice::ReadOnly))
        for (const auto &value : QJsonDocument::fromJson(file.readAll()).object().value("profiles").toArray())
            if (value.toObject().value("name").toString() == name) profile = value.toObject();
    if (profile.isEmpty()) { emit errorOccurred("This profile no longer exists."); return -1; }
    const QStringList onList = strings(profile.value("enabled")), offList = strings(profile.value("disabled"));
    const QSet<QString> on(onList.begin(), onList.end()), off(offList.begin(), offList.end());
    QStringList enable, disable;
    // Mods added after the profile was saved keep their current state.
    for (const auto &value : m_contents.mods) {
        const auto mod = value.toMap();
        const QString fileName = mod.value("fileName").toString();
        const bool enabled = mod.value("enabled").toBool();
        if (!enabled && on.contains(baseName(fileName))) enable << fileName;
        if (enabled && off.contains(baseName(fileName))) disable << fileName;
    }
    // Renamed directly and refreshed once, since each refresh clears the scanned list.
    int changed = 0;
    bool failed = false;
    for (const auto &fileName : enable) { if (renameMod(fileName, true)) ++changed; else failed = true; }
    for (const auto &fileName : disable) { if (renameMod(fileName, false)) ++changed; else failed = true; }
    if (failed) emit errorOccurred("Some mods could not be switched. Check file permissions and whether the target already exists.");
    if (changed) {
        m_model->reload();
        refresh();
    }
    return changed;
}
