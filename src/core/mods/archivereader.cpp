#include "archivereader.h"
#include "../system/archivefiles.h"
#include <QFile>
#include <archive.h>
#include <archive_entry.h>

// Reads the named entries (and, with a prefix, every entry under it) from an open archive.
static QHash<QString, QByteArray> readEntries(archive *reader, const QStringList &names, const QString &prefix, qint64 limit)
{
    QHash<QString, QByteArray> files;
    archive_entry *entry = nullptr;
    int entries = 0;
    while (entries++ < 100000 && archive_read_next_header(reader, &entry) == ARCHIVE_OK) {
        const QString name = ArchiveFiles::entryName(entry);
        const bool wanted = names.contains(name) || (!prefix.isEmpty() && name.startsWith(prefix) && !name.endsWith('/'));
        if (!wanted || archive_entry_size(entry) < 0 || archive_entry_size(entry) > limit) {
            archive_read_data_skip(reader);
            continue;
        }
        QByteArray data;
        char buffer[8192];
        la_ssize_t size;
        while ((size = archive_read_data(reader, buffer, sizeof buffer)) > 0 && data.size() + size <= limit)
            data.append(buffer, size);
        if (size == 0) files.insert(name, data);
    }
    return files;
}

QHash<QString, QByteArray> Mods::readArchiveFiles(const QString &path, const QStringList &names)
{
    QHash<QString, QByteArray> files;
    archive *reader = archive_read_new();
    archive_read_support_format_zip(reader);
    archive_read_support_filter_all(reader);
    if (ArchiveFiles::openRead(reader, path, 16384) == ARCHIVE_OK)
        files = readEntries(reader, names, {}, 2 * 1024 * 1024);
    archive_read_free(reader);
    return files;
}

QHash<QString, QByteArray> Mods::readArchiveFolder(const QString &path, const QString &prefix, qint64 limit)
{
    QHash<QString, QByteArray> files;
    archive *reader = archive_read_new();
    archive_read_support_format_zip(reader);
    if (ArchiveFiles::openRead(reader, path, 16384) == ARCHIVE_OK)
        files = readEntries(reader, {}, prefix, limit);
    archive_read_free(reader);
    return files;
}

QHash<QString, QByteArray> Mods::readArchiveBytes(const QByteArray &bytes, const QStringList &names)
{
    QHash<QString, QByteArray> files;
    archive *reader = archive_read_new();
    archive_read_support_format_zip(reader);
    if (archive_read_open_memory(reader, bytes.constData(), size_t(bytes.size())) == ARCHIVE_OK)
        files = readEntries(reader, names, {}, 2 * 1024 * 1024);
    archive_read_free(reader);
    return files;
}

QHash<QString, QByteArray> Mods::readMetadataFiles(const QString &path)
{
    return readArchiveFiles(path, {"fabric.mod.json", "quilt.mod.json", "META-INF/mods.toml",
        "META-INF/neoforge.mods.toml", "META-INF/MANIFEST.MF"});
}

QStringList Mods::archiveEntries(const QString &path, int limit)
{
    QStringList names;
    archive *reader = archive_read_new();
    archive_read_support_format_zip(reader);
    if (ArchiveFiles::openRead(reader, path, 16384) == ARCHIVE_OK) {
        archive_entry *entry = nullptr;
        while (names.size() < limit && archive_read_next_header(reader, &entry) == ARCHIVE_OK) {
            names.append(ArchiveFiles::entryName(entry));
            archive_read_data_skip(reader);
        }
    }
    archive_read_free(reader);
    return names;
}
