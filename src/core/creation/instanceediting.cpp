#include "instancecreator.h"
#include "../prism/configreader.h"
#include "../prism/configwriter.h"
#include "../prism/paths.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QSet>
#include <QTemporaryDir>
#include <QUuid>
#include <QtConcurrent>

namespace {
bool save(const QString &path, const QByteArray &bytes) {
    QSaveFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size() && file.commit();
}
QString copyTree(const QString &source, const QString &target, const QSet<QString> &excluded, const QString &relative = {}) {
    if (!QDir().mkpath(target)) return "Cannot create the copy's folders.";
    for (const auto &entry : QDir(source).entryInfoList(QDir::AllEntries | QDir::NoDotAndDotDot | QDir::Hidden | QDir::System)) {
        const QString name = entry.fileName(), path = relative.isEmpty() ? name : relative + "/" + name;
        if (excluded.contains(path) || name.startsWith(".prismarine") || name == "session.lock" || name == "instance.lock") continue;
        // Copies must be independent, and must not walk outside the selected instance.
        if (entry.isSymLink()) return "Cannot duplicate a symbolic link: " + path + ". Copy its contents into the instance first.";
        if (entry.isDir()) {
            const auto error = copyTree(entry.filePath(), target + "/" + name, excluded, path);
            if (!error.isEmpty()) return error;
        } else if (!entry.isFile() || !QFile::copy(entry.filePath(), target + "/" + name)) return "Cannot copy " + path + ".";
    }
    return {};
}
}
void InstanceCreator::duplicate(const QString &id, const QString &name, const QVariantMap &options)
{
    if (m_loading) return;
    m_error.clear();
    const QString source = m_model->instancePath(id), root = m_model->instanceDir();
    if (source.isEmpty() || name.trimmed().isEmpty() || name.contains(QRegularExpression("[\\r\\n\\x{0000}]"))) {
        m_error = "Choose an instance and a name for its copy."; emit changed(); return;
    }
    if (Prism::instanceRunning(source)) {
        m_error = "Stop this instance before duplicating it."; emit changed(); return;
    }
    m_loading = m_copying = true; emit changed();
    const QString game = QDir(source).relativeFilePath(Prism::gameDir(source));
    auto *watcher = new QFutureWatcher<QPair<QString, QString>>(this);
    connect(watcher, &QFutureWatcher<QPair<QString, QString>>::finished, this, [this, watcher] {
        const auto result = watcher->result(); watcher->deleteLater();
        m_loading = m_copying = false; m_error = result.second;
        if (!result.first.isEmpty()) { m_model->reload(); emit duplicated(result.first); }
        emit changed();
    });
    watcher->setFuture(QtConcurrent::run([source, root, name, options, game]() -> QPair<QString, QString> {
        QTemporaryDir staging(root + "/.prismarine-copy-XXXXXX");
        if (!staging.isValid()) return {{}, "Cannot prepare the copy."};
        QSet<QString> excluded{game + "/logs", game + "/crash-reports"};
        const QMap<QString, QStringList> choices{{"worlds", {"saves"}}, {"mods", {"mods"}},
            {"resources", {"resourcepacks", "shaderpacks"}}, {"screenshots", {"screenshots"}},
            {"options", {"options.txt", "optionsof.txt", "optionsshaders.txt"}}, {"servers", {"servers.dat", "servers.dat_old"}}};
        for (auto it = choices.cbegin(); it != choices.cend(); ++it)
            if (!options.value(it.key(), true).toBool()) for (const auto &folder : it.value()) excluded.insert(game + "/" + folder);
        auto error = copyTree(source, staging.path(), excluded);
        if (!error.isEmpty()) return {{}, error};
        QVariantMap cfg{{"name", name.trimmed()}, {"uuid", QUuid::createUuid().toString(QUuid::WithoutBraces)}, {"linkedInstances", "[]"}, {"shortcuts", ""}, {"InstanceRunning", false}, {"lastLaunchTime", 0}, {"lastTimePlayed", 0}};
        if (!options.value("playtime").toBool()) cfg.insert("totalTimePlayed", 0);
        if (!Prism::writeConfig(staging.path() + "/instance.cfg", cfg, &error)) return {{}, error};
        QString slug = name.trimmed(); slug.replace(QRegularExpression("[^A-Za-z0-9_-]+"), "-");
        const QString next = slug.left(64) + "-" + QUuid::createUuid().toString(QUuid::Id128).left(8);
        if (!QDir().rename(staging.path(), root + "/" + next)) return {{}, "Cannot finish the copy."};
        return {next, {}};
    }));
}
bool InstanceCreator::beginEdit(const QString &id)
{
    if (m_loading) return false;
    m_editId.clear(); m_manifest.clear(); m_error.clear();
    const QString path = m_model->instancePath(id);
    QFile file(path + "/mmc-pack.json");
    if (path.isEmpty() || !file.open(QIODevice::ReadOnly)) { m_error = "Cannot read this instance's versions."; emit changed(); return false; }
    m_manifest = file.readAll();
    if (!QJsonDocument::fromJson(m_manifest).object().value("components").isArray()) {
        m_error = "This instance has an invalid version manifest."; emit changed(); return false;
    }
    m_editId = id; return true;
}
bool InstanceCreator::changeVersions(const QString &minecraft, const QString &loader, const QString &loaderVersion)
{
    const auto fail = [this](const QString &e) { m_error = e; emit changed(); return false; };
    const QString path = m_model->instancePath(m_editId);
    if (m_loading || path.isEmpty()) return fail("Reopen the version editor before saving.");
    const auto has = [](const QVariantList &values, const QString &v) {
        for (const auto &value : values) if (value.toMap().value("version") == v) return true;
        return false;
    };
    if (!has(m_versions, minecraft) || (loader != "Vanilla" && (loader != m_loader || minecraft != m_minecraft || !has(m_loaderVersions, loaderVersion))))
        return fail("Choose compatible Minecraft and loader versions from the lists.");
    if (Prism::instanceRunning(path)) return fail("Stop this instance before changing versions.");
    QFile file(path + "/mmc-pack.json");
    if (!file.open(QIODevice::ReadOnly) || file.readAll() != m_manifest) return fail("The instance changed. Reopen the version editor.");
    file.close();
    const QMap<QString, QString> loaders{{"Fabric", "net.fabricmc.fabric-loader"}, {"Quilt", "org.quiltmc.quilt-loader"},
        {"Forge", "net.minecraftforge"}, {"NeoForge", "net.neoforged"}};
    if (loader != "Vanilla" && !loaders.contains(loader)) return fail("Unknown loader.");
    auto pack = QJsonDocument::fromJson(m_manifest).object(); QJsonArray components;
    auto managed = loaders.values(); managed << "net.minecraft" << "net.fabricmc.intermediary";
    for (const auto &value : pack.value("components").toArray()) {
        const auto uid = value.toObject().value("uid").toString();
        if (!managed.contains(uid)) components.append(value);
        else if (QFile::exists(path + "/patches/" + uid + ".json")) return fail("This instance has a custom component patch. Edit it in Prism before changing versions here.");
    }
    components.append(QJsonObject{{"uid", "net.minecraft"}, {"version", minecraft}, {"important", true}});
    if (loader == "Fabric" || loader == "Quilt") components.append(QJsonObject{{"uid", "net.fabricmc.intermediary"}, {"version", minecraft}, {"dependencyOnly", true}});
    if (loader != "Vanilla") components.append(QJsonObject{{"uid", loaders.value(loader)}, {"version", loaderVersion}});
    pack.insert("components", components);
    const QString backups = path + "/.prismarine-versions";
    if (!QDir().mkpath(backups) || !save(backups + "/" + QUuid::createUuid().toString(QUuid::Id128) + ".json", m_manifest)) return fail("Cannot back up the previous versions.");
    const auto updated = QJsonDocument(pack).toJson();
    if (!save(path + "/mmc-pack.json", updated)) return fail("Cannot save the new versions.");
    m_manifest = updated; m_error.clear(); m_model->reload(); emit modified(m_editId); emit changed(); return true;
}
