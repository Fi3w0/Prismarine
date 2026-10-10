#include "contentinstaller.h"
#include <QtConcurrent>
#include <QFutureWatcher>
#include <QDir>
#include <QFile>
#include <QCryptographicHash>
#include <QJsonDocument>
#include <QJsonArray>

void ContentInstaller::appendSelection(const QJsonArray &selected)
{
    for (const auto &version : selected) if (!appendVersion(version.toObject())) return;
    resolveNext();
}
void ContentInstaller::indexInstalled(const QJsonArray &selected)
{
    const auto generation = m_generation;
    const QString directory = m_target;
    auto *watcher = new QFutureWatcher<QJsonArray>(this);
    connect(watcher, &QFutureWatcher<QJsonArray>::finished, this, [this, watcher, selected, generation] {
        const auto hashes = watcher->result(); watcher->deleteLater();
        if (generation != m_generation) return;
        if (hashes.isEmpty()) { appendSelection(selected); return; }
        QNetworkRequest request(QUrl(m_apiRoot.toString() + "/version_files"));
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        request.setRawHeader("User-Agent", "Prismarine/0.4.0"); request.setTransferTimeout(20000);
        auto *reply = m_network.post(request, QJsonDocument(QJsonObject{{"hashes", hashes}, {"algorithm", "sha512"}}).toJson());
        m_reply = reply;
        connect(reply, &QNetworkReply::finished, this, [this, reply, selected, generation] {
            if (generation == m_generation) {
                const auto doc = QJsonDocument::fromJson(reply->readAll());
                if (reply->error() != QNetworkReply::NoError || !doc.isObject()) fail("Could not check installed versions. Retry before adding content.");
                else {
                    const auto versions = doc.object();
                    for (const auto &value : versions) {
                        const auto version = value.toObject();
                        m_installedProjects.insert(version.value("project_id").toString(), version.value("id").toString());
                    }
                    appendSelection(selected);
                }
            }
            reply->deleteLater();
        });
    });
    watcher->setFuture(QtConcurrent::run([directory] {
        QJsonArray hashes;
        for (const auto &name : QDir(directory).entryList({"*.jar", "*.jar.disabled", "*.zip"}, QDir::Files)) {
            QFile file(directory + "/" + name); QCryptographicHash hash(QCryptographicHash::Sha512);
            if (file.open(QIODevice::ReadOnly) && hash.addData(&file)) hashes.append(QString::fromLatin1(hash.result().toHex()));
        }
        return hashes;
    }));
}
