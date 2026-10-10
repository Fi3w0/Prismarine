#include "javamanager.h"
#include "../system/archivefiles.h"
#include <archive.h>
#include <archive_entry.h>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QSet>

QString JavaRuntime::unpack(const QString &archivePath, const QString &destination)
{
    if (!QDir().mkpath(destination)) return "Cannot create Java staging directory.";
    archive *reader = archive_read_new();
    archive_read_support_format_tar(reader); archive_read_support_format_zip(reader); archive_read_support_filter_all(reader);
    const auto fail = [&](const QString &error) { archive_read_free(reader); return error; };
    if (ArchiveFiles::openRead(reader, archivePath, 65536) != ARCHIVE_OK) return fail("Cannot read the Java archive.");
    QSet<QString> seen; QMap<QString, QString> links;
    archive_entry *entry = nullptr; qint64 total = 0; int status; bool java = false;
    const auto safe = [](const QString &path) {
        return !path.isEmpty() && !QDir::isAbsolutePath(path) && !path.contains('\\') && !path.contains(':')
            && !path.split('/').contains("..") && !path.contains(QChar(0));
    };
    while ((status = archive_read_next_header(reader, &entry)) == ARCHIVE_OK) {
        const QString name = ArchiveFiles::entryName(entry);
        if (!safe(name) || seen.size() > 30000) return fail("Java archive contains an unsafe path or too many entries.");
        const QString relative = QDir::cleanPath(name), target = destination + "/" + relative;
        if (seen.contains(relative)) return fail("Java archive contains duplicate paths.");
        seen.insert(relative);
        const auto type = archive_entry_filetype(entry);
        if (type == AE_IFDIR) { if (!QDir().mkpath(target)) return fail("Cannot create a Java directory."); continue; }
        if (archive_entry_symlink(entry) || archive_entry_hardlink(entry)) {
            const bool hard = archive_entry_hardlink(entry);
            QString link = QString::fromUtf8(hard ? archive_entry_hardlink(entry) : archive_entry_symlink(entry));
            if (QDir::isAbsolutePath(link) || link.contains('\\') || link.contains(':')) return fail("Java archive contains an external link.");
            link = QDir::cleanPath(hard ? link : QFileInfo(relative).path() + "/" + link);
            if (!safe(link)) return fail("Java archive contains an external link.");
            links.insert(relative, link); continue;
        }
        if (type != AE_IFREG || archive_entry_size(entry) < 0 || archive_entry_size(entry) > 512 * 1024 * 1024) return fail("Java archive contains an unsupported entry.");
        QFile output(target);
        if (!QDir().mkpath(QFileInfo(target).path()) || !output.open(QIODevice::WriteOnly | QIODevice::NewOnly)) return fail("Cannot unpack Java files.");
        char buffer[65536]; la_ssize_t size;
        while ((size = archive_read_data(reader, buffer, sizeof buffer)) > 0) {
            total += size;
            if (total > 1536LL * 1024 * 1024 || output.write(buffer, size) != size) return fail("Java archive exceeds the limit or could not be written.");
        }
        if (size < 0) return fail("Java archive is damaged.");
        output.close();
        auto permissions = QFileDevice::ReadOwner | QFileDevice::WriteOwner | QFileDevice::ReadGroup | QFileDevice::ReadOther;
        if (archive_entry_perm(entry) & 0111) permissions |= QFileDevice::ExeOwner | QFileDevice::ExeGroup | QFileDevice::ExeOther;
        if (!output.setPermissions(permissions)) return fail("Cannot set Java executable permissions.");
        java |= relative.endsWith("/bin/java") || relative.endsWith("/bin/java.exe");
    }
    if (status != ARCHIVE_EOF || !java) return fail("Java archive is incomplete or has no runtime.");
    // Materialize internal file links after regular files, keeping the installation self-contained.
    while (!links.isEmpty()) {
        bool copied = false;
        for (auto it = links.begin(); it != links.end();) {
            const QString source = destination + "/" + it.value(), target = destination + "/" + it.key();
            if (!QFileInfo(source).isFile()) { ++it; continue; }
            if (!QDir().mkpath(QFileInfo(target).path()) || !QFile::copy(source, target)) return fail("Cannot resolve a Java archive link.");
            it = links.erase(it); copied = true;
        }
        if (!copied) return fail("Java archive contains unresolved links.");
    }
    archive_read_free(reader); return {};
}
