#include "packimporter.h"
#include "../system/archivefiles.h"
#include "../prism/configwriter.h"
#include "../prism/configreader.h"
#include <archive.h>
#include <archive_entry.h>
#include <QDir>
#include <QFile>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRegularExpression>
#include <QSet>

static bool safePath(const QString &path)
{
    return !path.isEmpty() && !path.startsWith('/') && !path.contains('\\') && !path.contains(':')
        && !path.split('/').contains("..") && !path.contains(QChar(0));
}
static QByteArray bytes(const QString &path) { QFile f(path); return f.open(QIODevice::ReadOnly) ? f.readAll() : QByteArray(); }
PackPlan extractPack(const QString &source, const QString &staging)
{
    PackPlan plan;
    const auto fail = [&](const QString &error) { plan.error = error; return plan; };
    auto *reader = archive_read_new(); archive_read_support_format_zip(reader); archive_read_support_filter_all(reader);
    std::unique_ptr<archive, decltype(&archive_read_free)> owner(reader, archive_read_free);
    if (ArchiveFiles::openRead(reader, source, 65536) != ARCHIVE_OK) return fail("Cannot open this pack archive.");
    const QString raw = staging + "/raw"; QDir().mkpath(raw);
    archive_entry *entry; int result = ARCHIVE_OK, count = 0; qint64 total = 0;
    while ((result = archive_read_next_header(reader, &entry)) == ARCHIVE_OK) {
        const QString path = ArchiveFiles::entryName(entry);
        if (++count > 100000 || !safePath(path) || archive_entry_symlink(entry) || archive_entry_hardlink(entry)) return fail("The pack contains an unsafe archive entry.");
        if (archive_entry_filetype(entry) == AE_IFDIR) { QDir().mkpath(raw + "/" + path); continue; }
        if (archive_entry_filetype(entry) != AE_IFREG || archive_entry_size(entry) > 512LL * 1024 * 1024) return fail("Unsupported or oversized pack entry.");
        const QString destination = raw + "/" + path;
        if (!QDir().mkpath(QFileInfo(destination).absolutePath())) return fail("Cannot extract the pack.");
        QFile output(destination);
        if (!output.open(QIODevice::WriteOnly)) return fail("Cannot save a pack file.");
        char block[65536]; la_ssize_t size;
        while ((size = archive_read_data(reader, block, sizeof(block))) > 0) {
            total += size;
            if (total > 2LL * 1024 * 1024 * 1024 || output.write(block, size) != size) return fail("The extracted pack exceeds the size limit or cannot be saved.");
        }
        if (size < 0) return fail("The archive is damaged.");
    }
    if (result != ARCHIVE_EOF) return fail("The archive is damaged.");
    if (QFile::exists(raw + "/modrinth.index.json")) {
        const auto manifest = QJsonDocument::fromJson(bytes(raw + "/modrinth.index.json")).object();
        if (manifest.value("formatVersion") != 1 || manifest.value("game") != "minecraft") return fail("Unsupported Modrinth pack format.");
        plan.modrinth = true; plan.name = manifest.value("name").toString(); plan.instanceRoot = staging + "/instance";
        const auto deps = manifest.value("dependencies").toObject();
        if (deps.value("minecraft").toString().isEmpty()) return fail("This pack has no Minecraft version.");
        QJsonArray components{QJsonObject{{"uid", "net.minecraft"}, {"version", deps.value("minecraft")}, {"important", true}}};
        const QMap<QString, QString> loaders{{"fabric-loader", "net.fabricmc.fabric-loader"}, {"quilt-loader", "org.quiltmc.quilt-loader"}, {"forge", "net.minecraftforge"}, {"neoforge", "net.neoforged"}};
        for (auto it = deps.begin(); it != deps.end(); ++it) {
            if (it.key() == "minecraft") continue;
            if (!loaders.contains(it.key())) return fail("This pack requires an unsupported component: " + it.key());
            if (it.key() == "fabric-loader" || it.key() == "quilt-loader") components.append(QJsonObject{{"uid", "net.fabricmc.intermediary"}, {"version", deps.value("minecraft")}, {"dependencyOnly", true}});
            components.append(QJsonObject{{"uid", loaders.value(it.key())}, {"version", it.value()}});
        }
        if (!manifest.value("files").isArray()) return fail("This pack has no file manifest.");
        QSet<QString> paths;
        for (const auto &v : manifest.value("files").toArray()) {
            const auto file = v.toObject();
            if (file.value("env").toObject().value("client") == "unsupported") continue;
            const QString path = file.value("path").toString();
            if (!safePath(path) || paths.contains(path)) return fail("The pack manifest contains an unsafe or duplicate file path.");
            paths.insert(path);
            const auto downloads = file.value("downloads").toArray();
            const QString url = downloads.isEmpty() ? QString() : downloads.first().toString();
            const QString hash = file.value("hashes").toObject().value("sha512").toString();
            if (QUrl(url).scheme() != "https" || !QRegularExpression("^[a-fA-F0-9]{128}$").match(hash).hasMatch()) return fail("A pack download has no secure URL or verification hash.");
            plan.files.append(QVariantMap{{"path", path}, {"url", url}, {"sha512", hash.toLower()}});
        }
        QDir().mkpath(plan.instanceRoot + "/.minecraft");
        QFile pack(plan.instanceRoot + "/mmc-pack.json");
        const auto json = QJsonDocument(QJsonObject{{"formatVersion", 1}, {"components", components}}).toJson();
        if (!pack.open(QIODevice::WriteOnly) || pack.write(json) != json.size()) return fail("Cannot save the pack manifest.");
        QString error;
        if (!Prism::writeConfig(plan.instanceRoot + "/instance.cfg", {{"name", plan.name}, {"InstanceType", "OneSix"}, {"iconKey", "default"}}, &error, false)) return fail(error);
    } else {
        plan.instanceRoot = raw;
        if (!QFile::exists(raw + "/instance.cfg")) {
            const auto directories = QDir(raw).entryList(QDir::Dirs | QDir::NoDotAndDotDot);
            if (directories.size() == 1) plan.instanceRoot = raw + "/" + directories.first();
        }
        if (!QFile::exists(plan.instanceRoot + "/instance.cfg") || !QFile::exists(plan.instanceRoot + "/mmc-pack.json")) {
            // Other launchers' formats are recognised and passed to Prism rather than rejected.
            const QString root = QFile::exists(raw + "/manifest.json") ? raw : plan.instanceRoot;
            const QJsonObject manifest = QJsonDocument::fromJson(bytes(root + "/manifest.json")).object();
            if (manifest.value("manifestType") == "minecraftModpack") plan.name = "CurseForge";
            else if (QFile::exists(root + "/instance.json")) plan.name = "ATLauncher";
            else if (QFile::exists(root + "/bin/modpack.jar") || QFile::exists(root + "/bin/version.json")) plan.name = "Technic";
            else if (QFile::exists(root + "/version.json") && QDir(root).exists("overrides")) plan.name = "FTB";
            else return fail("This ZIP is not a modpack Prismarine or Prism recognises.");
            plan.foreign = true;
            return plan;
        }
        const auto cfg = Prism::readConfig(plan.instanceRoot + "/instance.cfg");
        const auto pack = QJsonDocument::fromJson(bytes(plan.instanceRoot + "/mmc-pack.json")).object();
        if (cfg.value("InstanceType") != "OneSix" || !pack.value("components").isArray()) return fail("This exported instance has an invalid version manifest.");
        plan.name = cfg.value("name");
    }
    return plan;
}
static bool merge(const QString &from, const QString &to)
{
    if (!QDir(from).exists()) return true;
    if (!QDir().mkpath(to)) return false;
    for (const auto &info : QDir(from).entryInfoList(QDir::AllEntries | QDir::Hidden | QDir::NoDotAndDotDot)) {
        const QString destination = to + "/" + info.fileName();
        if (info.isDir()) { if (!merge(info.filePath(), destination)) return false; }
        else { if (QFile::exists(destination) && !QFile::remove(destination)) return false; if (!QFile::copy(info.filePath(), destination)) return false; }
    }
    return true;
}
bool applyPackOverrides(const QString &staging, QString *error)
{
    const QString game = staging + "/instance/.minecraft";
    if (!merge(staging + "/raw/overrides", game) || !merge(staging + "/raw/client-overrides", game)) { *error = "Cannot apply pack overrides."; return false; }
    return true;
}
