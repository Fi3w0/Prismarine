#include "droppedfiles.h"
#include "../mods/archivereader.h"
#include "../mods/modmetadata.h"
#include "../prism/paths.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUuid>

static bool isZip(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) && file.read(4) == QByteArray("PK\003\004", 4);
}

QVariantMap DroppedFiles::inspectFile(const QString &path)
{
    const QFileInfo info(path);
    QVariantMap result{{"url", QUrl::fromLocalFile(info.absoluteFilePath())}, {"fileName", info.fileName()},
        {"name", info.completeBaseName()}, {"size", double(info.size())}, {"kind", "unknown"}, {"loaders", QStringList()}};
    if (!info.isFile() || info.isSymLink() || !isZip(path)) return result;
    const QString suffix = info.suffix().toLower();
    if (suffix == "mrpack") { result["kind"] = "modpack"; return result; }
    if (suffix == "jar") {
        const auto files = Mods::readMetadataFiles(path);
        QStringList loaders;
        if (files.contains("fabric.mod.json")) loaders << "Fabric";
        if (files.contains("quilt.mod.json")) loaders << "Quilt";
        if (files.contains("META-INF/neoforge.mods.toml")) loaders << "NeoForge";
        if (files.contains("META-INF/mods.toml")) loaders << "Forge";
        const auto metadata = Mods::readMetadata(info);
        result["kind"] = "mod";
        result["loaders"] = loaders;
        result["name"] = metadata.value("name");
        result["version"] = metadata.value("version");
        result["icon"] = metadata.value("icon");
        return result;
    }
    if (suffix != "zip") return result;
    const QStringList entries = Mods::archiveEntries(path);
    const auto atRoot = [&](const QString &name) { return entries.contains(name); };
    const auto nearRoot = [&](const QString &name) {
        for (const auto &entry : entries)
            if (entry == name || (entry.endsWith("/" + name) && entry.count('/') == 1)) return true;
        return false;
    };
    const auto folderAt = [&](const QString &folder, bool nested) {
        for (const auto &entry : entries)
            if (entry.startsWith(folder + "/") || (nested && entry.count('/') >= 2 && entry.section('/', 1, 1) == folder)) return true;
        return false;
    };
    if (atRoot("modrinth.index.json") || nearRoot("instance.cfg") || atRoot("instance.json") || atRoot("bin/modpack.jar")) {
        result["kind"] = "modpack";
    } else if (atRoot("manifest.json")
        && QJsonDocument::fromJson(Mods::readArchiveFiles(path, {"manifest.json"}).value("manifest.json")).object().value("manifestType") == "minecraftModpack") {
        result["kind"] = "modpack";
    } else if (folderAt("shaders", true)) {
        result["kind"] = "shader";
    } else if (atRoot("pack.mcmeta")) {
        result["kind"] = folderAt("data", false) && !folderAt("assets", false) ? "datapack" : "resourcepack";
    }
    return result;
}

QVariantList DroppedFiles::inspect(const QVariantList &urls) const
{
    QVariantList result;
    for (const auto &value : urls) {
        const QUrl url = value.toUrl();
        if (url.isLocalFile()) result.append(inspectFile(url.toLocalFile()));
        else result.append(QVariantMap{{"url", url}, {"fileName", url.fileName()}, {"name", url.fileName()}, {"kind", "unknown"}});
    }
    return result;
}

bool DroppedFiles::loaderMatches(const QStringList &modLoaders, const QString &instanceLoader)
{
    if (modLoaders.isEmpty()) return true; // Unknown metadata: let the user decide.
    if (modLoaders.contains(instanceLoader)) return true;
    if (instanceLoader == "Quilt" && modLoaders.contains("Fabric")) return true;
    return false;
}

QVariantMap DroppedFiles::install(const QString &instanceId, const QVariantList &urls, const QString &world)
{
    QVariantList skipped;
    int installed = 0;
    const QString path = m_model ? m_model->instancePath(instanceId) : QString();
    const auto skip = [&](const QString &fileName, const QString &reason) { skipped.append(QVariantMap{{"fileName", fileName}, {"reason", reason}}); };
    if (path.isEmpty()) {
        emit errorOccurred("This instance is no longer available.");
        return {{"installed", 0}, {"skipped", skipped}};
    }
    if (Prism::instanceRunning(path)) {
        emit errorOccurred("Stop this instance before adding files to it.");
        return {{"installed", 0}, {"skipped", skipped}};
    }
    QStringList names;
    for (const auto &value : urls) {
        // The kind is checked again here instead of trusting what the window was told.
        const QUrl url = value.toUrl();
        const auto file = url.isLocalFile() ? inspectFile(url.toLocalFile()) : QVariantMap{{"fileName", url.fileName()}, {"kind", "unknown"}};
        const QString kind = file.value("kind").toString(), fileName = file.value("fileName").toString();
        if (kind == "modpack") { skip(fileName, "Modpacks are imported as new instances."); continue; }
        if (kind == "unknown") { skip(fileName, "Not a mod, resource pack, shader or datapack."); continue; }
        if (kind == "datapack" && world.isEmpty()) { skip(fileName, "Choose a world for datapacks."); continue; }
        const QString folder = Prism::contentDir(path, kind, kind == "datapack" ? world : QString());
        if (folder.isEmpty() || !QDir().mkpath(folder)) { skip(fileName, "The destination folder is not available."); continue; }
        const QString target = folder + "/" + fileName;
        if (names.contains(folder + "/" + fileName) || QFileInfo::exists(target) || QFileInfo::exists(target + ".disabled")) {
            skip(fileName, "A file with this name is already installed."); continue;
        }
        // Copy beside the target under a hidden name, then rename, so loaders never see a partial file.
        const QString partial = folder + "/." + QUuid::createUuid().toString(QUuid::Id128) + ".prismarine-part";
        if (!QFile::copy(url.toLocalFile(), partial) || !QFile::rename(partial, target)) {
            QFile::remove(partial);
            skip(fileName, "Could not copy this file.");
            continue;
        }
        names.append(target);
        ++installed;
    }
    if (installed) {
        m_model->reload();
        emit this->installed(instanceId, installed);
    }
    return {{"installed", installed}, {"skipped", skipped}};
}
