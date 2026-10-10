#include "modupdater.h"
#include "../prism/paths.h"
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QRegularExpression>
#include <QUuid>
#include <QtConcurrent>

namespace {
constexpr qint64 MaxDownload = 256 * 1024 * 1024;

struct HashedFile { QString fileName, sha512; };

QList<HashedFile> hashMods(const QString &directory, const QString &type)
{
    QList<HashedFile> files;
    for (const QString &name : QDir(directory).entryList(type == "mod" ? QStringList{"*.jar", "*.jar.disabled"} : QStringList{"*.zip", "*.zip.disabled"}, QDir::Files | QDir::NoSymLinks, QDir::Name)) {
        QFile file(directory + "/" + name);
        QCryptographicHash hash(QCryptographicHash::Sha512);
        if (file.open(QIODevice::ReadOnly) && hash.addData(&file))
            files.append({name, QString::fromLatin1(hash.result().toHex())});
    }
    return files;
}
}

ModUpdater::ModUpdater(InstanceModel *model, QObject *parent, const QUrl &apiRoot)
    : QObject(parent), m_model(model), m_apiRoot(apiRoot)
{
}

QVariantMap ModUpdater::byFile() const
{
    QVariantMap map;
    for (const QVariant &update : m_updates) map.insert(update.toMap().value("fileName").toString(), update);
    return map;
}

void ModUpdater::fail(const QString &message)
{
    m_state = QStringLiteral("error");
    m_error = message;
    emit changed();
}

void ModUpdater::check(const QString &instanceId, const QString &type, const QString &world)
{
    const QString path = m_model->instancePath(instanceId);
    if (path.isEmpty() || m_state == "updating") return;
    const quint64 generation = ++m_generation;
    if (m_reply) m_reply->abort();
    const QVariantMap info = m_model->getById(instanceId);
    m_instanceId = instanceId;
    m_type = type; m_world = world;
    m_modsDir = Prism::contentDir(path, type, world);
    if (m_modsDir.isEmpty()) { fail("Choose a valid content folder or saved world."); return; }
    m_updates.clear();
    m_error.clear();
    m_progress = 0;
    m_state = QStringLiteral("checking");
    emit changed();
    const QString loader = type == "mod" ? info.value("loader").toString().toLower() : type == "datapack" ? "datapack" : "", version = info.value("version").toString();
    auto *watcher = new QFutureWatcher<QList<HashedFile>>(this);
    connect(watcher, &QFutureWatcher<QList<HashedFile>>::finished, this, [this, watcher, generation, loader, version] {
        const QList<HashedFile> files = watcher->result();
        watcher->deleteLater();
        if (generation != m_generation) return;
        if (files.isEmpty()) { m_state = QStringLiteral("ready"); emit changed(); return; }
        QJsonArray hashes;
        QMap<QString, QString> nameByHash;
        for (const HashedFile &file : files) { hashes.append(file.sha512); nameByHash.insert(file.sha512, file.fileName); }
        QJsonObject body{{"hashes", hashes}, {"algorithm", "sha512"}};
        if (!version.isEmpty()) body.insert("game_versions", QJsonArray{version});
        if (QStringList{"fabric", "forge", "neoforge", "quilt", "datapack"}.contains(loader)) body.insert("loaders", QJsonArray{loader});
        QNetworkRequest request(QUrl(m_apiRoot.toString() + "/version_files/update"));
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        request.setRawHeader("User-Agent", "Prismarine/0.4.0 (Qt desktop UI)");
        request.setTransferTimeout(20000);
        auto *reply = m_network.post(request, QJsonDocument(body).toJson(QJsonDocument::Compact));
        m_reply = reply;
        connect(reply, &QNetworkReply::finished, this, [this, reply, generation, nameByHash] {
            reply->deleteLater();
            if (generation != m_generation) return;
            const auto doc = QJsonDocument::fromJson(reply->readAll());
            if (reply->error() != QNetworkReply::NoError || !doc.isObject()) { fail("Could not check Modrinth for updates."); return; }
            const QJsonObject latest = doc.object();
            for (auto it = latest.begin(); it != latest.end(); ++it) {
                const QString fileName = nameByHash.value(it.key());
                const QJsonObject version = it.value().toObject();
                QJsonObject primary;
                bool current = false;
                for (const auto &value : version.value("files").toArray()) {
                    const QJsonObject file = value.toObject();
                    current |= file.value("hashes").toObject().value("sha512").toString() == it.key();
                    if (file.value("filename").toString().endsWith(m_type == "mod" ? ".jar" : ".zip", Qt::CaseInsensitive) && (primary.isEmpty() || file.value("primary").toBool())) primary = file;
                }
                const QString newName = primary.value("filename").toString();
                const QString sha512 = primary.value("hashes").toObject().value("sha512").toString();
                if (fileName.isEmpty() || current || !newName.endsWith(m_type == "mod" ? ".jar" : ".zip", Qt::CaseInsensitive)
                    || newName.startsWith('.') || newName.contains(QRegularExpression("[/\\\\\\x{0000}-\\x{001f}]"))
                    || !QRegularExpression("^[a-fA-F0-9]{128}$").match(sha512).hasMatch()) continue;
                m_updates.append(QVariantMap{{"fileName", fileName}, {"newFileName", newName},
                                             {"version", version.value("version_number").toString()},
                                             {"projectId", version.value("project_id").toString()},
                                             {"url", primary.value("url").toString()}, {"sha512", sha512.toLower()}, {"oldHash", it.key()},
                                             {"size", primary.value("size").toInteger()}});
            }
            m_state = QStringLiteral("ready");
            emit changed();
        });
    });
    watcher->setFuture(QtConcurrent::run(hashMods, m_modsDir, m_type));
}

void ModUpdater::update(const QStringList &fileNames)
{
    if (m_state != "ready" || m_updates.isEmpty()) return;
    m_queue.clear();
    for (const QVariant &value : m_updates)
        if (fileNames.isEmpty() || fileNames.contains(value.toMap().value("fileName").toString())) m_queue.append(value);
    if (m_queue.isEmpty()) return;
    m_downloaded.clear();
    m_index = 0;
    m_progress = 0;
    m_state = QStringLiteral("updating");
    emit changed();
    downloadNext();
}

void ModUpdater::cancel()
{
    ++m_generation;
    if (m_reply) m_reply->abort();
    m_downloaded.clear();
    m_state = m_updates.isEmpty() ? QStringLiteral("idle") : QStringLiteral("ready");
    emit changed();
}

void ModUpdater::downloadNext()
{
    if (m_index >= m_queue.size()) { commit(); return; }
    const QVariantMap item = m_queue.at(m_index).toMap();
    const QUrl url(item.value("url").toString());
    if (url.scheme() != "https" && !(m_apiRoot.scheme() == "http" && url.scheme() == "http")) { fail("Modrinth returned an unsafe download link."); return; }
    const quint64 generation = m_generation;
    QNetworkRequest request(url);
    request.setRawHeader("User-Agent", "Prismarine/0.4.0 (Qt desktop UI)");
    request.setTransferTimeout(30000);
    auto *reply = m_network.get(request);
    m_reply = reply;
    auto bytes = std::make_shared<QByteArray>();
    connect(reply, &QNetworkReply::readyRead, this, [reply, bytes] {
        bytes->append(reply->readAll());
        if (bytes->size() > MaxDownload) reply->abort();
    });
    connect(reply, &QNetworkReply::downloadProgress, this, [this, generation](qint64 received, qint64 total) {
        if (generation != m_generation) return;
        m_progress = (m_index + (total > 0 ? qMin(1.0, double(received) / total) : 0)) / m_queue.size();
        emit changed();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, bytes, generation, item] {
        reply->deleteLater();
        if (generation != m_generation) return;
        bytes->append(reply->readAll());
        if (reply->error() != QNetworkReply::NoError) fail("Download failed. " + reply->errorString());
        else if (QCryptographicHash::hash(*bytes, QCryptographicHash::Sha512).toHex() != item.value("sha512").toByteArray())
            fail("Download verification failed for " + item.value("newFileName").toString() + ". Nothing was replaced.");
        else {
            m_downloaded.append(*bytes);
            ++m_index;
            downloadNext();
        }
    });
}

void ModUpdater::commit()
{
    if (Prism::contentDir(m_model->instancePath(m_instanceId), m_type, m_world) != m_modsDir) { fail("The content folder changed. Nothing was replaced."); return; }
    // Everything is downloaded and verified before any installed file changes.
    const QString removed = QFileInfo(m_modsDir).path() + "/.prismarine-removed/" + QUuid::createUuid().toString(QUuid::Id128);
    int count = 0;
    QStringList skipped, done;
    for (int i = 0; i < m_queue.size(); ++i) {
        const QVariantMap item = m_queue.at(i).toMap();
        const QString oldName = item.value("fileName").toString();
        const bool disabled = oldName.endsWith(".disabled");
        const QString newName = item.value("newFileName").toString() + (disabled ? ".disabled" : "");
        const QString oldPath = m_modsDir + "/" + oldName, newPath = m_modsDir + "/" + newName;
        QFile old(oldPath); QCryptographicHash original(QCryptographicHash::Sha512);
        if (QFileInfo(oldPath).isSymLink() || !old.open(QIODevice::ReadOnly) || !original.addData(&old)
            || original.result().toHex() != item.value("oldHash").toByteArray()) { skipped.append(newName); continue; }
        old.close();
        if (newName != oldName && QFile::exists(newPath)) { skipped.append(newName); continue; }
        // Keep a copy of a same-named jar, since writing replaces it in place.
        if (newName == oldName && !(QDir().mkpath(removed) && (QFile::exists(removed + "/" + oldName) || QFile::copy(oldPath, removed + "/" + oldName)))) {
            skipped.append(newName);
            continue;
        }
        QSaveFile output(newPath);
        if (!output.open(QIODevice::WriteOnly) || output.write(m_downloaded.at(i)) != m_downloaded.at(i).size() || !output.commit()) {
            skipped.append(newName);
            continue;
        }
        // The new jar is in place; only now does the old one leave, and if it cannot, the new one goes.
        if (newName != oldName && QFile::exists(oldPath)
            && !QFile::moveToTrash(oldPath)
            && !(QDir().mkpath(removed) && !QFile::exists(removed + "/" + oldName) && QFile::rename(oldPath, removed + "/" + oldName))) {
            QFile::remove(newPath);
            skipped.append(newName);
            continue;
        }
        ++count; done.append(oldName);
    }
    m_downloaded.clear();
    QVariantList remaining;
    for (const QVariant &value : m_updates)
        if (!done.contains(value.toMap().value("fileName").toString())) remaining.append(value);
    m_updates = remaining;
    m_queue.clear();
    m_progress = 1;
    m_state = QStringLiteral("ready");
    if (!skipped.isEmpty()) m_error = "Kept the current file for: " + skipped.join(", ");
    emit changed();
    emit updated(m_instanceId, count);
}
