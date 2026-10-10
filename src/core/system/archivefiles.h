#pragma once
#include <QDir>
#include <QFile>
#include <QString>
#include <archive.h>
#include <archive_entry.h>

// libarchive with Unicode file names on every system: on Windows the narrow functions use
// the ANSI code page, which cannot name every folder (for example a user name with accents).
namespace ArchiveFiles {
inline int openRead(archive *reader, const QString &path, size_t blockSize)
{
#ifdef Q_OS_WIN
    return archive_read_open_filename_w(reader, reinterpret_cast<const wchar_t *>(QDir::toNativeSeparators(path).utf16()), blockSize);
#else
    return archive_read_open_filename(reader, QFile::encodeName(path).constData(), blockSize);
#endif
}

inline int openWrite(archive *writer, const QString &path)
{
#ifdef Q_OS_WIN
    return archive_write_open_filename_w(writer, reinterpret_cast<const wchar_t *>(QDir::toNativeSeparators(path).utf16()));
#else
    return archive_write_open_filename(writer, QFile::encodeName(path).constData());
#endif
}

// The entry's name as stored (zip and tar names are UTF-8 in practice), or empty.
inline QString entryName(archive_entry *entry)
{
    if (const char *utf8 = archive_entry_pathname_utf8(entry)) return QString::fromUtf8(utf8);
    const char *raw = archive_entry_pathname(entry);
    return raw ? QString::fromUtf8(raw) : QString();
}
}
