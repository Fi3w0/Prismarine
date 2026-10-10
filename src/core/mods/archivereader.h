#pragma once
#include <QHash>
#include <QByteArray>
#include <QString>
#include <QStringList>
namespace Mods {
QHash<QString, QByteArray> readArchiveFiles(const QString &path, const QStringList &names);
QHash<QString, QByteArray> readMetadataFiles(const QString &path);
// Every file under `prefix` (e.g. "META-INF/jars/"), each at most `limit` bytes.
QHash<QString, QByteArray> readArchiveFolder(const QString &path, const QString &prefix, qint64 limit);
// Named entries of a ZIP held in memory, such as a jar nested in another jar.
QHash<QString, QByteArray> readArchiveBytes(const QByteArray &bytes, const QStringList &names);
// Entry names of a ZIP archive, at most `limit` of them; empty if it cannot be read.
QStringList archiveEntries(const QString &path, int limit = 50000);
}
