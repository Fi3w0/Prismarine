#include "contentinstaller.h"
#include "../prism/paths.h"
#include <QFile>
#include <QDir>
#include <QCryptographicHash>

void ContentInstaller::install()
{
    if (m_state != "ready" || m_plan.isEmpty()) return;
    if (Prism::contentDir(m_model->instancePath(m_id), m_type, m_world) != m_target) { fail("The destination changed. Review the installation again."); return; }
    if (!QDir().mkpath(m_target)) { fail("Cannot create the content folder."); return; }
    m_staging = std::make_unique<QTemporaryDir>(m_target + "/.prismarine-install-XXXXXX");
    if (!m_staging->isValid()) { fail("Cannot prepare downloads."); return; }
    m_downloadIndex = 0; m_progress = 0; m_state = "downloading"; emit changed(); downloadNext();
}
void ContentInstaller::downloadNext()
{
    if (m_downloadIndex >= m_plan.size()) { commit(); return; }
    const auto file = m_plan.at(m_downloadIndex).toMap();
    const auto generation = m_generation;
    QNetworkRequest request(file.value("url").toUrl()); request.setTransferTimeout(30000);
    request.setRawHeader("User-Agent", "Prismarine/0.4.0");
    auto *reply = m_network.get(request); m_reply = reply;
    auto bytes = std::make_shared<QByteArray>();
    connect(reply, &QNetworkReply::readyRead, this, [reply, bytes] {
        bytes->append(reply->readAll());
        if (bytes->size() > 256 * 1024 * 1024) reply->abort();
    });
    connect(reply, &QNetworkReply::downloadProgress, this, [this, generation](qint64 received, qint64 total) {
        if (generation != m_generation) return;
        m_progress = (m_downloadIndex + (total > 0 ? qMin(1.0, double(received) / total) : 0)) / m_plan.size(); emit changed();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, bytes, generation, file] {
        if (generation == m_generation && m_state == "downloading") {
            bytes->append(reply->readAll());
            if (bytes->size() > 256 * 1024 * 1024) fail("This download exceeds the 256 MiB file limit.");
            else if (reply->error() != QNetworkReply::NoError) fail("Download failed. " + reply->errorString());
            else if (QCryptographicHash::hash(*bytes, file.value("algorithm") == "sha1" ? QCryptographicHash::Sha1 : QCryptographicHash::Sha512).toHex() != file.value("hash").toByteArray())
                fail("Download verification failed for " + file.value("filename").toString() + ". No files were installed.");
            else {
                QFile output(m_staging->path() + "/" + file.value("filename").toString());
                if (!output.open(QIODevice::WriteOnly) || output.write(*bytes) != bytes->size()) fail("Cannot save the verified download.");
                else { output.close(); ++m_downloadIndex; downloadNext(); }
            }
        }
        reply->deleteLater();
    });
}
void ContentInstaller::commit()
{
    if (Prism::contentDir(m_model->instancePath(m_id), m_type, m_world) != m_target) { fail("The destination changed. No files were installed."); return; }
    QStringList added;
    int count = 0;
    for (const auto &value : m_plan) {
        const auto item = value.toMap();
        const QString name = item.value("filename").toString(), target = m_target + "/" + name;
        // Refuse to overwrite different installed files; identical dependencies need no copy.
        if (QFile::exists(target)) {
            QFile existing(target);
            QCryptographicHash hash(item.value("algorithm") == "sha1" ? QCryptographicHash::Sha1 : QCryptographicHash::Sha512);
            if (!existing.open(QIODevice::ReadOnly) || !hash.addData(&existing)
                || hash.result().toHex() != item.value("hash").toByteArray()) {
                for (const auto &path : added) QFile::remove(path);
                fail("An installed file already uses " + name + ". No existing files were replaced."); return;
            }
            continue;
        }
        if (!QFile::rename(m_staging->path() + "/" + name, target)) {
            for (const auto &path : added) QFile::remove(path);
            fail("Cannot install " + name + ". The new files were rolled back."); return;
        }
        added.append(target); ++count;
    }
    m_staging.reset(); m_state = "complete"; m_progress = 1;
    m_model->reload(); emit changed(); emit installed(m_id, count);
}
