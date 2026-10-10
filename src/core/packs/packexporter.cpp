#include "packexporter.h"
#include "../system/archivefiles.h"
#include "../prism/paths.h"
#include <archive.h>
#include <archive_entry.h>
#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QtConcurrent>
#include <QCoreApplication>
#include <algorithm>
#include <memory>

namespace {
// Never shared: personal, generated, or launcher-private files.
const QStringList &excludedTop()
{
    static const QStringList names{"logs", "crash-reports", "screenshots", "natives", ".cache", "cache", "downloads", "backups",
                                   ".fabric", ".mixin.out", ".prismarine-removed", "usercache.json", "usernamecache.json",
                                   "realms_persistence.json", "command_history.txt", ".replay_cache", "replay_recordings", "essential"};
    return names;
}

bool hasPrefix(const QString &relative, const QString &folder) { return relative == folder || relative.startsWith(folder + "/"); }

void hashFile(ExportFile &file)
{
    QFile input(file.absolute);
    QCryptographicHash sha1(QCryptographicHash::Sha1), sha512(QCryptographicHash::Sha512);
    if (!input.open(QIODevice::ReadOnly)) return;
    while (!input.atEnd()) {
        const QByteArray block = input.read(1 << 20);
        sha1.addData(block);
        sha512.addData(block);
    }
    file.sha1 = QString::fromLatin1(sha1.result().toHex());
    file.sha512 = QString::fromLatin1(sha512.result().toHex());
}

bool addEntry(archive *writer, const QString &name, const QString &source, QString *error)
{
    QFile input(source);
    if (!input.open(QIODevice::ReadOnly)) { *error = "Cannot read " + name; return false; }
    std::unique_ptr<archive_entry, decltype(&archive_entry_free)> entry(archive_entry_new(), archive_entry_free);
    archive_entry_set_pathname_utf8(entry.get(), name.toUtf8().constData());
    archive_entry_set_size(entry.get(), input.size());
    archive_entry_set_filetype(entry.get(), AE_IFREG);
    archive_entry_set_perm(entry.get(), 0644);
    if (archive_write_header(writer, entry.get()) != ARCHIVE_OK) { *error = QString::fromUtf8(archive_error_string(writer)); return false; }
    while (!input.atEnd()) {
        const QByteArray block = input.read(1 << 20);
        if (archive_write_data(writer, block.constData(), size_t(block.size())) < 0) { *error = QString::fromUtf8(archive_error_string(writer)); return false; }
    }
    return true;
}

bool addBytes(archive *writer, const QString &name, const QByteArray &bytes, QString *error)
{
    std::unique_ptr<archive_entry, decltype(&archive_entry_free)> entry(archive_entry_new(), archive_entry_free);
    archive_entry_set_pathname_utf8(entry.get(), name.toUtf8().constData());
    archive_entry_set_size(entry.get(), bytes.size());
    archive_entry_set_filetype(entry.get(), AE_IFREG);
    archive_entry_set_perm(entry.get(), 0644);
    if (archive_write_header(writer, entry.get()) != ARCHIVE_OK || archive_write_data(writer, bytes.constData(), size_t(bytes.size())) < 0) {
        *error = QString::fromUtf8(archive_error_string(writer));
        return false;
    }
    return true;
}
}

PackExporter::PackExporter(InstanceModel *model, QObject *parent, const QUrl &apiRoot)
    : QObject(parent), m_model(model), m_apiRoot(apiRoot)
{
}

void PackExporter::fail(const QString &message)
{
    m_state = QStringLiteral("error");
    m_error = message;
    emit changed();
}

void PackExporter::cancel()
{
    ++m_generation;
    if (m_reply) m_reply->abort();
    m_state = QStringLiteral("idle");
    emit changed();
}

QList<ExportFile> PackExporter::chooseFiles(const QString &gameDir, const QVariantMap &options)
{
    QList<ExportFile> files;
    const QDir root(gameDir);
    QDirIterator it(gameDir, QDir::Files | QDir::Hidden | QDir::NoSymLinks, QDirIterator::Subdirectories);
    while (it.hasNext()) {
        const QString absolute = it.next();
        const QString relative = root.relativeFilePath(absolute);
        const QString top = relative.section('/', 0, 0);
        if (excludedTop().contains(top) || top.startsWith(".prismarine") || relative.endsWith(".log") || relative.endsWith(".log.gz")) continue;
        // Worlds and per-player map or chunk caches can be huge and are personal; they go only with worlds.
        static const QStringList worldData{"saves", "xaero", "XaeroWaypoints", "XaeroWorldMap", "journeymap", "voxelmap", "mods/VoxelMods",
                                           ".bobby", "Distant_Horizons_server_data", "distant_horizons_server_data", "moddata/ftbchunks"};
        if (std::any_of(worldData.begin(), worldData.end(), [&](const QString &f) { return hasPrefix(relative, f); }) && !options.value("worlds").toBool()) continue;
        // Prism's update metadata for the mods folder describes this machine's files, not the pack's.
        if (hasPrefix(relative, "mods/.index") && options.value("format").toString() == "mrpack") continue;
        if ((hasPrefix(relative, "config") || hasPrefix(relative, "defaultconfigs") || hasPrefix(relative, "kubejs")) && !options.value("configs", true).toBool()) continue;
        if ((hasPrefix(relative, "resourcepacks") || hasPrefix(relative, "shaderpacks")) && !options.value("resources", true).toBool()) continue;
        if ((relative == "options.txt" || relative == "optionsof.txt" || relative == "optionsshaders.txt") && !options.value("options").toBool()) continue;
        if (relative == "servers.dat" || relative == "servers.dat_old") { if (!options.value("servers").toBool() || relative.endsWith("_old")) continue; }
        if (relative.endsWith(".disabled") && !options.value("disabled").toBool()) continue;
        ExportFile file;
        file.relative = relative;
        file.absolute = absolute;
        file.size = QFileInfo(absolute).size();
        files.append(file);
    }
    std::sort(files.begin(), files.end(), [](const ExportFile &a, const ExportFile &b) { return a.relative < b.relative; });
    return files;
}

void PackExporter::exportPack(const QString &instanceId, const QUrl &destination, const QString &format, const QVariantMap &options)
{
    if (m_state == "preparing" || m_state == "exporting") return;
    const QString path = m_model->instancePath(instanceId);
    if (path.isEmpty() || !destination.isLocalFile()) { fail("Choose where to save the pack."); return; }
    const quint64 generation = ++m_generation;
    m_instanceId = instanceId;
    m_instancePath = path;
    m_gameDir = Prism::gameDir(path);
    m_format = format == "zip" ? QStringLiteral("zip") : QStringLiteral("mrpack");
    m_options = options;
    m_name = m_model->getById(instanceId).value("name").toString();
    m_output = destination.toLocalFile();
    if (!m_output.endsWith("." + m_format, Qt::CaseInsensitive)) m_output += "." + m_format;
    m_error.clear();
    m_summary.clear();
    m_progress = 0;
    m_state = QStringLiteral("preparing");
    emit changed();
    const QString gameDir = m_gameDir;
    const bool mrpack = m_format == "mrpack";
    auto *watcher = new QFutureWatcher<QList<ExportFile>>(this);
    connect(watcher, &QFutureWatcher<QList<ExportFile>>::finished, this, [this, watcher, generation, mrpack] {
        QList<ExportFile> files = watcher->result();
        watcher->deleteLater();
        if (generation != m_generation) return;
        if (mrpack) lookUp(files);
        else write(files);
    });
    watcher->setFuture(QtConcurrent::run([gameDir, options, mrpack] {
        QVariantMap choice = options;
        choice.insert("format", mrpack ? "mrpack" : "zip");
        QList<ExportFile> files = chooseFiles(gameDir, choice);
        // Only content that Modrinth could host needs hashing.
        if (mrpack)
            for (ExportFile &file : files)
                if (hasPrefix(file.relative, "mods") || hasPrefix(file.relative, "resourcepacks") || hasPrefix(file.relative, "shaderpacks")) hashFile(file);
        return files;
    }));
}

void PackExporter::lookUp(QList<ExportFile> files)
{
    QJsonArray hashes;
    for (const ExportFile &file : files) if (!file.sha512.isEmpty()) hashes.append(file.sha512);
    if (hashes.isEmpty()) { write(files); return; }
    const quint64 generation = m_generation;
    QNetworkRequest request(QUrl(m_apiRoot.toString() + "/version_files"));
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    request.setRawHeader("User-Agent", "Prismarine/0.4.0 (Qt desktop UI)");
    request.setTransferTimeout(30000);
    auto *reply = m_network.post(request, QJsonDocument(QJsonObject{{"hashes", hashes}, {"algorithm", "sha512"}}).toJson(QJsonDocument::Compact));
    m_reply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, files, generation]() mutable {
        reply->deleteLater();
        if (generation != m_generation) return;
        // Offline or Modrinth down: still export, with every file as an override.
        const QJsonObject versions = reply->error() == QNetworkReply::NoError ? QJsonDocument::fromJson(reply->readAll()).object() : QJsonObject();
        for (ExportFile &file : files) {
            const QJsonObject version = versions.value(file.sha512).toObject();
            for (const auto &value : version.value("files").toArray()) {
                const QJsonObject hosted = value.toObject();
                const QString url = hosted.value("url").toString();
                if (hosted.value("hashes").toObject().value("sha512").toString() == file.sha512 && url.startsWith("https://")) file.url = url;
            }
        }
        write(files);
    });
}

void PackExporter::write(const QList<ExportFile> &files)
{
    m_state = QStringLiteral("exporting");
    emit changed();
    const quint64 generation = m_generation;
    const QString output = m_output, format = m_format, instancePath = m_instancePath, gameDir = m_gameDir, name = m_name;
    const QVariantMap info = m_model->getById(m_instanceId), options = m_options;
    QPointer<PackExporter> self(this);
    auto *watcher = new QFutureWatcher<QString>(this);
    connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher, generation, files] {
        const QString error = watcher->result();
        watcher->deleteLater();
        if (generation != m_generation) return;
        if (!error.isEmpty()) { fail(error); return; }
        int hosted = 0, included = 0;
        for (const ExportFile &file : files) (file.url.isEmpty() ? included : hosted) += 1;
        m_summary = {{"downloads", hosted}, {"files", included}, {"bytes", QFileInfo(m_output).size()}};
        m_progress = 1;
        m_state = QStringLiteral("complete");
        emit changed();
        emit exported(m_output);
    });
    watcher->setFuture(QtConcurrent::run([=]() -> QString {
        const QString partial = output + ".part";
        QFile::remove(partial);
        std::unique_ptr<archive, decltype(&archive_write_free)> writer(archive_write_new(), archive_write_free);
        archive_write_set_format_zip(writer.get());
        if (ArchiveFiles::openWrite(writer.get(), partial) != ARCHIVE_OK) return "Cannot create " + output;
        QString error;
        const auto report = [&](int done) {
            QMetaObject::invokeMethod(qApp, [self, generation, done, total = files.size()] {
                if (self && generation == self->m_generation) { self->m_progress = double(done) / qMax<qsizetype>(1, total); emit self->changed(); }
            });
        };
        if (format == "mrpack") {
            QJsonArray manifestFiles;
            for (const ExportFile &file : files) {
                if (file.url.isEmpty()) continue;
                manifestFiles.append(QJsonObject{{"path", file.relative}, {"hashes", QJsonObject{{"sha1", file.sha1}, {"sha512", file.sha512}}},
                                                 {"downloads", QJsonArray{file.url}}, {"fileSize", file.size}});
            }
            QJsonObject dependencies{{"minecraft", info.value("version").toString()}};
            const QMap<QString, QString> loaders{{"Fabric", "fabric-loader"}, {"Quilt", "quilt-loader"}, {"Forge", "forge"}, {"NeoForge", "neoforge"}};
            if (loaders.contains(info.value("loader").toString()))
                dependencies.insert(loaders.value(info.value("loader").toString()), info.value("loaderVersion").toString());
            const QJsonObject manifest{{"formatVersion", 1}, {"game", "minecraft"}, {"versionId", options.value("version", "1.0.0").toString()},
                                       {"name", name}, {"summary", options.value("description").toString()},
                                       {"files", manifestFiles}, {"dependencies", dependencies}};
            if (!addBytes(writer.get(), "modrinth.index.json", QJsonDocument(manifest).toJson(), &error)) return error;
            int done = 0;
            for (const ExportFile &file : files) {
                if (file.url.isEmpty() && !addEntry(writer.get(), "overrides/" + file.relative, file.absolute, &error)) return error;
                report(++done);
            }
        } else {
            // A Prism/MultiMC export: instance files at the root, the game folder beside them.
            for (const QString &meta : {QStringLiteral("instance.cfg"), QStringLiteral("mmc-pack.json"), QStringLiteral("icon.png")})
                if (QFile::exists(instancePath + "/" + meta) && !addEntry(writer.get(), meta, instancePath + "/" + meta, &error)) return error;
            const QString folder = QFileInfo(gameDir).fileName();
            int done = 0;
            for (const ExportFile &file : files) {
                if (!addEntry(writer.get(), folder + "/" + file.relative, file.absolute, &error)) return error;
                report(++done);
            }
        }
        if (archive_write_close(writer.get()) != ARCHIVE_OK) return QString::fromUtf8(archive_error_string(writer.get()));
        writer.reset();
        QFile::remove(output);
        if (!QFile::rename(partial, output)) return "Cannot save " + output;
        return {};
    }));
}
