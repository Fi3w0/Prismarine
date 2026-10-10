#include "packimporter.h"
#include <QCryptographicHash>
#include <QFile>
#include <QDir>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QUuid>

void PackImporter::downloadNext()
{
    if (m_index >= m_plan.files.size()) { finish(); return; }
    const auto file = m_plan.files[m_index].toMap(); const auto generation = m_generation;
    QNetworkRequest req(file.value("url").toUrl()); req.setRawHeader("User-Agent", "Prismarine/0.4.0"); req.setTransferTimeout(30000);
    auto *reply = m_network.get(req); m_reply = reply;
    auto bytes = std::make_shared<QByteArray>();
    connect(reply, &QNetworkReply::readyRead, this, [reply, bytes] { bytes->append(reply->readAll()); if (bytes->size() > 256 * 1024 * 1024) reply->abort(); });
    connect(reply, &QNetworkReply::downloadProgress, this, [this, generation](qint64 received, qint64 total) {
        if (generation != m_generation) return;
        m_progress = (m_index + (total > 0 ? qMin(1.0, double(received) / total) : 0)) / m_plan.files.size(); emit changed();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, bytes, file, generation] {
        if (generation == m_generation && m_state == "downloading") {
            bytes->append(reply->readAll());
            if (bytes->size() > 256 * 1024 * 1024) fail("A pack download exceeds the 256 MiB file limit.");
            else if (reply->error() != QNetworkReply::NoError) fail("Pack download failed. " + reply->errorString());
            else if (QCryptographicHash::hash(*bytes, QCryptographicHash::Sha512).toHex() != file.value("sha512").toByteArray()) fail("Pack download verification failed. No instance was imported.");
            else {
                const QString target = m_plan.instanceRoot + "/.minecraft/" + file.value("path").toString();
                QFile output(target);
                if (!QDir().mkpath(QFileInfo(target).absolutePath()) || !output.open(QIODevice::WriteOnly) || output.write(*bytes) != bytes->size()) fail("Cannot save a pack download.");
                else { output.close(); ++m_index; downloadNext(); }
            }
        }
        reply->deleteLater();
    });
}

void PackImporter::importVersion(const QVariantMap &version)
{
    if (m_state == "extracting" || m_state == "downloading" || m_state == "fetching") return;
    cancel();
    const bool curse = version.value("provider") == "curseforge";
    QVariantMap file;
    for (const auto &entry : version.value("files").toList()) {
        const auto candidate = entry.toMap();
        if (candidate.value("filename").toString().endsWith(curse ? ".zip" : ".mrpack") && (file.isEmpty() || candidate.value("primary").toBool())) file = candidate;
    }
    const QUrl url = file.value("url").toUrl();
    const auto algorithm = curse ? QCryptographicHash::Sha1 : QCryptographicHash::Sha512;
    const QByteArray expected = file.value("hashes").toMap().value(curse ? "sha1" : "sha512").toByteArray().toLower();
    if ((url.scheme() != "https" && !(m_api.scheme() == "http" && url.scheme() == "http")) || !QRegularExpression(curse ? "^[a-f0-9]{40}$" : "^[a-f0-9]{128}$").match(QString::fromLatin1(expected)).hasMatch()) { fail("This release has no verified pack download. Check its project website."); return; }
    m_archive = std::make_shared<QTemporaryDir>();
    if (!m_archive->isValid()) { fail("Cannot prepare the pack download."); return; }
    const auto storage = m_archive;
    auto output = std::make_shared<QFile>(storage->path() + "/pack.mrpack");
    if (!output->open(QIODevice::WriteOnly)) { fail("Cannot save the pack download."); return; }
    auto hash = std::make_shared<QCryptographicHash>(algorithm);
    auto count = std::make_shared<qint64>(0);
    const auto generation = m_generation;
    m_state = "fetching"; emit changed();
    QNetworkRequest request(url); request.setTransferTimeout(30000); request.setRawHeader("User-Agent", "Prismarine/0.4.0");
    auto *reply = m_network.get(request); m_reply = reply;
    connect(reply, &QNetworkReply::readyRead, this, [reply, output, hash, count] {
        const auto bytes = reply->readAll(); *count += bytes.size();
        if (*count > 512 * 1024 * 1024 || output->write(bytes) != bytes.size()) { reply->abort(); return; }
        hash->addData(bytes);
    });
    connect(reply, &QNetworkReply::downloadProgress, this, [this, generation](qint64 received, qint64 total) {
        if (generation == m_generation) { m_progress = total > 0 ? double(received) / total : 0; emit changed(); }
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, output, hash, expected, storage, generation, curse] {
        reply->deleteLater(); output->close();
        if (generation != m_generation) return;
        if (reply->error() != QNetworkReply::NoError) { fail("Pack download failed. No instance was created."); return; }
        if (hash->result().toHex() != expected) { fail("Pack verification failed. No instance was created."); return; }
        if (curse) {
            // Prism imports asynchronously; keep the verified ZIP in cache beyond this app's lifetime.
            const QString cache = QStandardPaths::writableLocation(QStandardPaths::CacheLocation) + "/packs";
            const QString path = cache + "/" + QUuid::createUuid().toString(QUuid::Id128) + ".zip";
            if (!QDir().mkpath(cache) || !QFile::copy(output->fileName(), path)) { fail("Cannot keep the verified pack for Prism's importer."); return; }
            importFile(QUrl::fromLocalFile(path));
        } else {
            importFile(QUrl::fromLocalFile(output->fileName()));
            m_archive = storage;
        }
    });
}
