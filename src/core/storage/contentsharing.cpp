#include "storagemanager.h"
#include "../prism/paths.h"
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFutureWatcher>
#include <QHash>
#include <QMap>
#include <QUuid>
#include <QtConcurrent>
#include "../system/system.h"

// Shared content: identical mods, resource packs and shader packs in several instances
// become hard links to one copy. Every instance keeps its own directory entry, so
// renaming (disabling), deleting or replacing a file in one instance never touches the
// others. Files are only ever replaced by an identical file, atomically.
namespace {
const QStringList sharedFolders{"mods", "resourcepacks", "shaderpacks"};
constexpr qint64 minimumShared = 64 * 1024;

using FileId = Sys::FileId;
// Only plain files count; links are never followed out of an instance.
FileId fileId(const QString &path)
{
    const QFileInfo info(path);
    return info.isFile() && !info.isSymLink() ? Sys::fileId(path) : FileId();
}

QByteArray sha1(const QString &path)
{
    QFile file(path);
    QCryptographicHash hash(QCryptographicHash::Sha1);
    if (!file.open(QIODevice::ReadOnly) || !hash.addData(&file)) return {};
    return hash.result();
}
}

QStringList StorageManager::sharedContentFiles(const QStringList &instancePaths)
{
    QStringList files;
    for (const auto &instance : instancePaths) {
        const QString game = Prism::gameDir(instance);
        for (const auto &folder : sharedFolders)
            for (const auto &entry : QDir(game + "/" + folder).entryInfoList(QDir::Files | QDir::NoSymLinks, QDir::Name))
                if (!entry.fileName().startsWith('.') && entry.size() >= minimumShared) files << entry.absoluteFilePath();
    }
    return files;
}

QVector<QStringList> StorageManager::duplicateGroups(const QStringList &files)
{
    QMap<qint64, QStringList> bySize;
    for (const auto &file : files) bySize[QFileInfo(file).size()] << file;
    QVector<QStringList> groups;
    for (const auto &candidates : bySize) {
        if (candidates.size() < 2) continue;
        QHash<QByteArray, QStringList> byHash;
        for (const auto &file : candidates) if (const auto hash = sha1(file); !hash.isEmpty()) byHash[hash] << file;
        for (const auto &group : byHash) {
            if (group.size() < 2) continue;
            // Already one file: nothing left to share.
            const FileId first = fileId(group.first());
            bool allLinked = first.valid;
            for (const auto &file : group) { const auto id = fileId(file); allLinked &= id.valid && id.device == first.device && id.inode == first.inode; }
            if (!allLinked) groups << group;
        }
    }
    return groups;
}

QVariantMap StorageManager::linkGroups(const QVector<QStringList> &groups)
{
    int linked = 0, skipped = 0;
    qint64 freed = 0;
    if (!Sys::hardLinksSupported()) return {{"linked", 0}, {"skipped", int(groups.size())}, {"freed", 0.0}};
    for (const auto &group : groups) {
        const QString canonical = group.first();
        const FileId source = fileId(canonical);
        const QByteArray expected = sha1(canonical);
        for (const auto &target : group.mid(1)) {
            const FileId id = fileId(target);
            if (!source.valid || !id.valid) { ++skipped; continue; }
            if (id.device == source.device && id.inode == source.inode) continue;
            // Re-check just before replacing, in case the file changed since the scan.
            if (id.device != source.device || sha1(target) != expected) { ++skipped; continue; }
            const QString temporary = QFileInfo(target).path() + "/." + QUuid::createUuid().toString(QUuid::Id128) + ".prismarine-link";
            // Hard links need one file system (on Windows: one NTFS volume); otherwise skipped.
            if (!Sys::hardLink(canonical, temporary)) { ++skipped; continue; }
            if (!Sys::replaceFile(temporary, target)) {
                QFile::remove(temporary);
                ++skipped;
                continue;
            }
            ++linked;
            if (id.links <= 1) freed += QFileInfo(canonical).size();
        }
    }
    return {{"linked", linked}, {"skipped", skipped}, {"freed", double(freed)}};
}

int StorageManager::unshareFiles(const QStringList &files)
{
    int separated = 0;
    for (const auto &file : files) {
        const FileId id = fileId(file);
        if (!id.valid || id.links < 2) continue;
        const QString temporary = QFileInfo(file).path() + "/." + QUuid::createUuid().toString(QUuid::Id128) + ".prismarine-copy";
        if (!QFile::copy(file, temporary)) { QFile::remove(temporary); continue; }
        if (Sys::replaceFile(temporary, file)) ++separated;
        else QFile::remove(temporary);
    }
    return separated;
}

QVariantMap StorageManager::sharingSummary(const QStringList &files)
{
    // Bytes saved: every extra name for the same inode inside instance content folders.
    QHash<QPair<quint64, quint64>, QPair<qint64, int>> seen;
    for (const auto &file : files) {
        const FileId id = fileId(file);
        if (!id.valid || id.links < 2) continue;
        auto &entry = seen[{id.device, id.inode}];
        entry.first = QFileInfo(file).size();
        ++entry.second;
    }
    qint64 saved = 0;
    int shared = 0;
    for (const auto &entry : seen) if (entry.second > 1) { saved += entry.first * (entry.second - 1); shared += entry.second; }
    return {{"sharedFiles", shared}, {"saved", double(saved)}};
}

QStringList StorageManager::idleInstancePaths() const
{
    QStringList paths;
    if (!m_model) return paths;
    for (const auto &value : m_model->allInstances() + m_model->copies()) {
        const QString path = m_model->instancePath(value.toMap().value("instanceId").toString());
        if (!Prism::instanceRunning(path)) paths << path;
    }
    return paths;
}

void StorageManager::findDuplicates()
{
    if (m_sharing.value("checking").toBool()) return;
    m_sharing.insert("checking", true);
    emit changed();
    const QStringList paths = idleInstancePaths();
    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher] {
        watcher->deleteLater();
        m_sharing = watcher->result();
        m_sharing.insert("checked", true);
        emit changed();
    });
    watcher->setFuture(QtConcurrent::run([paths] {
        const QStringList files = sharedContentFiles(paths);
        const auto groups = duplicateGroups(files);
        qint64 savings = 0;
        int duplicates = 0;
        for (const auto &group : groups) {
            // Count each distinct inode beyond the first once.
            QSet<QPair<quint64, quint64>> inodes;
            for (const auto &file : group) { const auto id = fileId(file); inodes.insert({id.device, id.inode}); }
            duplicates += inodes.size() - 1;
            savings += QFileInfo(group.first()).size() * (inodes.size() - 1);
        }
        QVariantMap result = sharingSummary(files);
        result.insert("duplicates", duplicates);
        result.insert("savings", double(savings));
        return result;
    }));
}

QVariantMap StorageManager::shareDuplicates()
{
    const QStringList files = sharedContentFiles(idleInstancePaths());
    const QVariantMap result = linkGroups(duplicateGroups(files));
    m_sharing = sharingSummary(files);
    m_sharing.insert("duplicates", 0);
    m_sharing.insert("savings", 0.0);
    m_sharing.insert("checked", true);
    emit changed();
    return result;
}

int StorageManager::unshareAll()
{
    const QStringList files = sharedContentFiles(idleInstancePaths());
    const int separated = unshareFiles(files);
    m_sharing = sharingSummary(files);
    m_sharing.insert("checked", false);
    emit changed();
    return separated;
}
