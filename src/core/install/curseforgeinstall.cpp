#include "contentinstaller.h"
#include "../catalog/curseforge.h"
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFutureWatcher>
#include <QJsonArray>
#include <QRegularExpression>
#include <QUrlQuery>
#include <QtConcurrent>
#include <algorithm>

void ContentInstaller::resolveCurseForge(const QJsonObject &dependency)
{
    const QString project = dependency.value("project_id").toString();
    if (m_projects.contains(project) || m_installedProjects.contains(project)) { resolveNext(); return; }
    if (!QRegularExpression("^cf:[1-9][0-9]*$").match(project).hasMatch()) { fail("A dependency has an invalid CurseForge project ID."); return; }
    QUrl url(m_curseApi.toString() + "/mods/" + project.mid(3) + "/files"); QUrlQuery query;
    query.addQueryItem("gameVersion", m_gameVersion); query.addQueryItem("pageSize", "50");
    if (m_type == "mod") query.addQueryItem("modLoaderType", QString::number(CurseForge::loaderId(m_loader)));
    url.setQuery(query);
    getJson(url, [this](const QJsonDocument &doc) {
        QList<QJsonObject> versions;
        for (const auto &value : doc.object().value("data").toArray()) {
            const auto file = value.toObject(); if (!file.value("isAvailable").toBool(true)) continue;
            auto v = CurseForge::version(file);
            if (m_type == "datapack") v.insert("loaders", QJsonArray{"datapack"});
            if (!v.value("game_versions").toArray().contains(m_gameVersion) || (m_type == "mod" && !v.value("loaders").toArray().contains(m_loader))) continue;
            versions.append(v);
        }
        std::stable_sort(versions.begin(), versions.end(), [](const QJsonObject &a, const QJsonObject &b) { return a.value("date_published").toString() > b.value("date_published").toString(); });
        if (versions.isEmpty()) { fail("A required CurseForge dependency has no compatible release."); return; }
        if (appendVersion(versions.first())) resolveNext();
    });
}
void ContentInstaller::indexCurseForge(const QJsonArray &selected)
{
    const auto generation = m_generation; const QString directory = m_target;
    auto *watcher = new QFutureWatcher<QJsonObject>(this);
    connect(watcher, &QFutureWatcher<QJsonObject>::finished, this, [this, watcher, selected, generation] {
        const auto found = watcher->result(); watcher->deleteLater(); if (generation != m_generation) return;
        const auto fingerprints = found.value("fingerprints").toArray(), hashes = found.value("sha1").toArray();
        if (fingerprints.isEmpty()) { appendSelection(selected); return; }
        QNetworkRequest request(QUrl(m_curseApi.toString() + "/fingerprints/432"));
        request.setTransferTimeout(20000); request.setRawHeader("User-Agent", "Prismarine/0.4.0"); request.setRawHeader("x-api-key", m_curseKey);
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        auto *reply = m_network.post(request, QJsonDocument(QJsonObject{{"fingerprints", fingerprints}}).toJson()); m_reply = reply;
        connect(reply, &QNetworkReply::finished, this, [this, reply, generation, selected, hashes] {
            reply->deleteLater(); if (generation != m_generation) return;
            const auto data = QJsonDocument::fromJson(reply->readAll()).object().value("data").toObject();
            if (reply->error() != QNetworkReply::NoError || !data.value("exactMatches").isArray()) { fail("Could not check installed CurseForge files. Retry before installing."); return; }
            for (const auto &entry : data.value("exactMatches").toArray()) {
                const auto v = CurseForge::version(entry.toObject().value("file").toObject());
                const auto files = v.value("files").toArray();
                const QString hash = files.first().toObject().value("hashes").toObject().value("sha1").toString().toLower();
                if (hashes.contains(hash)) m_installedProjects.insert(v.value("project_id").toString(), v.value("id").toString());
            }
            appendSelection(selected);
        });
    });
    watcher->setFuture(QtConcurrent::run([directory] {
        QJsonArray fingerprints, hashes;
        for (const auto &name : QDir(directory).entryList({"*.jar", "*.jar.disabled", "*.zip"}, QDir::Files | QDir::NoSymLinks)) {
            QFile file(directory + "/" + name);
            if (file.size() > 256 * 1024 * 1024 || !file.open(QIODevice::ReadOnly)) continue;
            const auto bytes = file.readAll(); fingerprints.append(qint64(CurseForge::fingerprint(bytes)));
            hashes.append(QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha1).toHex()));
        }
        return QJsonObject{{"fingerprints", fingerprints}, {"sha1", hashes}};
    }));
}
