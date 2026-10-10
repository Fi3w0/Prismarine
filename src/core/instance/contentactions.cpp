#include "instancedetails.h"
#include "../prism/paths.h"
#include <QUuid>
#include <QJsonDocument>
#include <QJsonObject>
#include "../mods/archivereader.h"
#include <QDesktopServices>
#include <QDir>
#include <QFile>
#include <QUrl>

bool InstanceDetails::hasMod(const QString &fileName) const
{
    for (const auto &value : m_contents.mods)
        if (value.toMap().value("fileName").toString() == fileName) return true;
    return false;
}
bool InstanceDetails::renameMod(const QString &fileName, bool enabled)
{
    if (fileName.endsWith(".disabled") != enabled) return true;
    const QString target = enabled ? fileName.left(fileName.size() - 9) : fileName + ".disabled";
    return QFile::rename(m_gamePath + "/mods/" + fileName, m_gamePath + "/mods/" + target);
}
bool InstanceDetails::setModEnabled(const QString &fileName, bool enabled)
{
    return setModsEnabled({fileName}, enabled) == 1;
}
int InstanceDetails::setModsEnabled(const QStringList &fileNames, bool enabled)
{
    if (m_loading) return 0;
    int changed = 0;
    bool failed = false;
    for (const QString &fileName : fileNames) {
        if (!hasMod(fileName)) continue;
        if (renameMod(fileName, enabled)) ++changed;
        else failed = true;
    }
    if (failed)
        emit errorOccurred("Could not change this mod. Check file permissions and whether the target already exists.");
    if (changed) {
        m_model->reload();
        refresh();
    }
    return changed;
}
// Removed mods are recoverable: they go to the system trash, or to a folder outside mods/ that loaders never scan.
int InstanceDetails::removeMods(const QStringList &fileNames)
{
    if (m_loading) return 0;
    const QString keep = m_gamePath + "/.prismarine-removed";
    int removed = 0;
    bool failed = false;
    for (const QString &fileName : fileNames) {
        if (!hasMod(fileName)) continue;
        const QString source = m_gamePath + "/mods/" + fileName;
        if (QFile::moveToTrash(source) || (QDir().mkpath(keep) && !QFile::exists(keep + "/" + fileName) && QFile::rename(source, keep + "/" + fileName)))
            ++removed;
        else
            failed = true;
    }
    if (failed)
        emit errorOccurred("Some mods could not be removed. Check file permissions.");
    if (removed) {
        m_model->reload();
        refresh();
    }
    return removed;
}
bool InstanceDetails::openContentFolder(const QString &category)
{
    const QStringList allowed{"mods", "resourcepacks", "shaderpacks", "saves", "logs", "screenshots", "config"};
    if (m_gamePath.isEmpty() || !allowed.contains(category) || !QDir(m_gamePath + "/" + category).exists()) {
        emit errorOccurred("This folder has not been created yet.");
        return false;
    }
    if (QDesktopServices::openUrl(QUrl::fromLocalFile(m_gamePath + "/" + category))) return true;
    emit errorOccurred("Could not open the folder.");
    return false;
}

bool InstanceDetails::addMods(const QVariantList &urls)
{
    if (m_gamePath.isEmpty() || m_loading || urls.isEmpty()) return false;
    if (!QDir().mkpath(m_gamePath + "/mods")) {
        emit errorOccurred("Could not create the mods folder.");
        return false;
    }
    QStringList sources;
    for (const auto &value : urls) {
        const QUrl url = value.toUrl();
        const QFileInfo file(url.toLocalFile());
        QFile jar(file.absoluteFilePath());
        const QString destination = m_gamePath + "/mods/" + file.fileName();
        if (!url.isLocalFile() || !file.isFile() || !file.fileName().endsWith(".jar", Qt::CaseInsensitive)
            || !jar.open(QIODevice::ReadOnly) || jar.read(4) != QByteArray("PK\003\004", 4)) {
            emit errorOccurred("Choose valid Minecraft .jar files.");
            return false;
        }
        if (QFileInfo::exists(destination) || QFileInfo::exists(destination + ".disabled")
            || sources.contains(file.absoluteFilePath())) {
            emit errorOccurred("A mod with this filename is already installed.");
            return false;
        }
        for (const auto &source : sources) {
            if (QFileInfo(source).fileName() == file.fileName()) {
                emit errorOccurred("Two selected mods have the same filename.");
                return false;
            }
        }
        sources.append(file.absoluteFilePath());
    }
    bool success = true;
    for (const auto &source : sources) {
        if (!QFile::copy(source, m_gamePath + "/mods/" + QFileInfo(source).fileName())) {
            emit errorOccurred("Could not copy " + QFileInfo(source).fileName() + ". Files already copied remain installed.");
            success = false;
            break;
        }
    }
    m_model->reload();
    refresh();
    return success;
}
bool InstanceDetails::openFile(const QString &fileName, const QString &category)
{
    for (const auto &value : m_contents.files) {
        const auto file = value.toMap();
        if (file.value("fileName").toString() == fileName && file.value("category").toString() == category)
            return QDesktopServices::openUrl(QUrl::fromLocalFile(m_gamePath + "/" + category + "/" + fileName));
    }
    return false;
}
bool InstanceDetails::openScreenshot(const QString &fileName)
{
    for (const auto &value : m_contents.screenshots)
        if (value.toMap().value("fileName").toString() == fileName)
            return QDesktopServices::openUrl(QUrl(value.toMap().value("url").toString()));
    return false;
}
QString InstanceDetails::readLog(const QString &fileName) const
{
    for (const auto &value : m_contents.files) {
        const auto file = value.toMap();
        if (file.value("category") == "logs" && file.value("fileName") == fileName) {
            QFile log(m_gamePath + "/logs/" + fileName);
            if (!log.open(QIODevice::ReadOnly)) return "Could not read this log.";
            if (log.size() > 256 * 1024) log.seek(log.size() - 256 * 1024);
            return QString::fromUtf8(log.readAll());
        }
    }
    return {};
}

QVariantList InstanceDetails::datapacks(const QString &world) const
{
    const QString path = Prism::contentDir(m_model->instancePath(m_id), "datapack", world);
    QVariantList result;
    if (path.isEmpty()) return result;
    for (const auto &file : QDir(path).entryInfoList(QDir::Files | QDir::Dirs | QDir::NoDotAndDotDot | QDir::NoSymLinks, QDir::Name)) {
        if (file.fileName().startsWith('.')) continue;
        if (file.isDir() ? !QFile::exists(file.filePath() + "/pack.mcmeta") : !file.fileName().endsWith(".zip", Qt::CaseInsensitive)) continue;
        result.append(QVariantMap{{"fileName", file.fileName()}, {"directory", file.isDir()}});
    }
    return result;
}
bool InstanceDetails::removeDatapack(const QString &world, const QString &name)
{
    const QString path = Prism::contentDir(m_model->instancePath(m_id), "datapack", world);
    bool known = false;
    for (const auto &entry : datapacks(world)) known |= entry.toMap().value("fileName") == name;
    if (path.isEmpty() || !known) return false;
    const QString keep = QFileInfo(path).path() + "/.prismarine-removed/" + QUuid::createUuid().toString(QUuid::Id128);
    if (!QFile::moveToTrash(path + "/" + name) && !(QDir().mkpath(keep) && QDir().rename(path + "/" + name, keep + "/" + name))) {
        emit errorOccurred("Could not remove this datapack."); return false;
    }
    emit changed(); return true;
}
bool InstanceDetails::addDatapacks(const QString &world, const QVariantList &urls)
{
    const QString path = Prism::contentDir(m_model->instancePath(m_id), "datapack", world);
    if (path.isEmpty() || urls.isEmpty() || !QDir().mkpath(path)) return false;
    QStringList added;
    for (const auto &value : urls) {
        const QUrl url = value.toUrl(); const QFileInfo source(url.toLocalFile()); QFile file(source.filePath());
        const QString target = path + "/" + source.fileName();
        if (!url.isLocalFile() || !source.isFile() || !source.fileName().endsWith(".zip", Qt::CaseInsensitive)
            || !file.open(QIODevice::ReadOnly) || file.read(4) != QByteArray("PK\003\004", 4)
            || !QJsonDocument::fromJson(Mods::readArchiveFiles(source.filePath(), {"pack.mcmeta"}).value("pack.mcmeta")).object().value("pack").isObject()
            || QFile::exists(target) || !QFile::copy(source.filePath(), target)) {
            for (const auto &created : added) QFile::remove(created);
            emit errorOccurred("Choose ZIP datapacks with names that are not already installed."); return false;
        }
        added.append(target);
    }
    emit changed(); return true;
}
