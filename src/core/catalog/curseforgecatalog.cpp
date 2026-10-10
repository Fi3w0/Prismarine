#include "modcatalog.h"
#include "curseforge.h"
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QTextDocument>
#include <QUrlQuery>
#include <algorithm>
#ifdef PRISMARINE_HAS_KEYCHAIN
#include <qt6keychain/keychain.h>
#endif

void ModCatalog::setProvider(const QString &provider)
{
    if ((provider != "modrinth" && provider != "curseforge") || provider == m_provider) return;
    m_provider = provider; ++m_searchGeneration; ++m_versionGeneration; ++m_projectGeneration;
    m_results.clear(); m_versions.clear(); m_project.clear(); m_error.clear(); m_loading = m_versionsLoading = false;
    emit changed(); emit categoriesChanged();
}
void ModCatalog::loadCredentials()
{
#ifdef PRISMARINE_HAS_KEYCHAIN
    if (!m_curseKey.isEmpty()) return;
    const auto generation = m_credentialsGeneration;
    auto *job = new QKeychain::ReadPasswordJob("Prismarine", this);
    job->setKey("curseforge-api-key"); job->setInsecureFallback(false);
    connect(job, &QKeychain::Job::finished, this, [this, job, generation] {
        if (!job->error() && generation == m_credentialsGeneration) { m_curseKey = job->binaryData(); emit credentialsChanged(); }
    });
    job->start();
#endif
}
void ModCatalog::setCurseForgeKey(const QString &key, bool remember)
{
    ++m_credentialsGeneration;
    m_curseKey = key.trimmed().toUtf8();
    if (m_curseKey.contains('\n') || m_curseKey.contains('\r')) m_curseKey.clear();
    m_error.clear(); emit credentialsChanged(); emit changed();
    if (!remember) return;
#ifdef PRISMARINE_HAS_KEYCHAIN
    auto *job = new QKeychain::WritePasswordJob("Prismarine", this);
    job->setKey("curseforge-api-key"); job->setInsecureFallback(false); job->setBinaryData(m_curseKey);
    connect(job, &QKeychain::Job::finished, this, [this, job] {
        if (job->error()) { m_error = "The key works for this session, but could not be saved in the system keyring."; emit changed(); }
    });
    job->start();
#else
    m_error = "The key works for this session. This build has no system keyring support."; emit changed();
#endif
}
QNetworkRequest ModCatalog::curseRequest(const QUrl &url) const
{
    auto req = request(url); req.setRawHeader("x-api-key", m_curseKey);
    req.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    return req;
}
void ModCatalog::searchCurseForge(const QString &query, const QString &version, const QString &loader, const QString &type, quint64 generation)
{
    if (m_curseKey.isEmpty()) { m_loading = false; m_error = "Add a CurseForge API key to browse this provider."; emit changed(); return; }
    const int classId = QMap<QString, int>{{"mod", 6}, {"modpack", 4471}, {"resourcepack", 12}, {"shader", 6552}, {"datapack", 6945}}.value(type);
    QUrl url(m_curseApi.toString() + "/mods/search"); QUrlQuery params;
    params.addQueryItem("gameId", "432"); params.addQueryItem("classId", QString::number(classId)); params.addQueryItem("pageSize", "50");
    params.addQueryItem("searchFilter", query); params.addQueryItem("sortField", "2"); params.addQueryItem("sortOrder", "desc");
    if (!version.isEmpty()) params.addQueryItem("gameVersion", version);
    if (type == "mod" && CurseForge::loaderId(loader)) params.addQueryItem("modLoaderType", QString::number(CurseForge::loaderId(loader)));
    url.setQuery(params); auto *reply = m_network.get(curseRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation, type] {
        reply->deleteLater(); if (generation != m_searchGeneration) return;
        m_loading = false; const auto data = QJsonDocument::fromJson(reply->readAll()).object().value("data");
        if (reply->error() != QNetworkReply::NoError || !data.isArray()) m_error = "CurseForge could not load results. Check the API key and connection.";
        else for (const auto &entry : data.toArray()) {
            const auto mod = entry.toObject(); QStringList authors;
            for (const auto &author : mod.value("authors").toArray()) authors.append(author.toObject().value("name").toString());
            m_results.append(QVariantMap{{"project_id", "cf:" + QString::number(mod.value("id").toInteger())}, {"title", mod.value("name").toString()},
                {"description", mod.value("summary").toString()}, {"icon_url", mod.value("logo").toObject().value("thumbnailUrl").toString()},
                {"slug", mod.value("slug").toString()}, {"author", authors.join(", ")}, {"project_type", type}, {"provider", "curseforge"},
                {"website", mod.value("links").toObject().value("websiteUrl").toString()}});
        }
        emit changed();
    });
}
void ModCatalog::curseForgeVersions(const QString &id, const QString &version, const QString &loader, quint64 generation)
{
    if (m_curseKey.isEmpty() || !QRegularExpression("^cf:[1-9][0-9]*$").match(id).hasMatch()) { m_versionsLoading = false; emit changed(); return; }
    QUrl url(m_curseApi.toString() + "/mods/" + id.mid(3) + "/files"); QUrlQuery params;
    params.addQueryItem("pageSize", "50");
    if (!version.isEmpty()) params.addQueryItem("gameVersion", version);
    if (CurseForge::loaderId(loader)) params.addQueryItem("modLoaderType", QString::number(CurseForge::loaderId(loader)));
    url.setQuery(params); auto *reply = m_network.get(curseRequest(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation, loader] {
        reply->deleteLater(); if (generation != m_versionGeneration) return;
        m_versionsLoading = false; const auto data = QJsonDocument::fromJson(reply->readAll()).object().value("data");
        if (reply->error() != QNetworkReply::NoError || !data.isArray()) m_error = "Could not load CurseForge releases.";
        else {
            for (const auto &entry : data.toArray()) {
                if (!entry.toObject().value("isAvailable").toBool(true) || entry.toObject().value("isServerPack").toBool()) continue;
                auto v = CurseForge::version(entry.toObject());
                if (loader == "datapack") v.insert("loaders", QJsonArray{"datapack"});
                m_versions.append(v.toVariantMap());
            }
            std::stable_sort(m_versions.begin(), m_versions.end(), [](const QVariant &a, const QVariant &b) { return a.toMap().value("date_published").toString() > b.toMap().value("date_published").toString(); });
        }
        emit changed();
    });
}
void ModCatalog::curseForgeProject(const QString &id, quint64 generation)
{
    if (m_curseKey.isEmpty() || !QRegularExpression("^cf:[1-9][0-9]*$").match(id).hasMatch()) return;
    auto *reply = m_network.get(curseRequest(QUrl(m_curseApi.toString() + "/mods/" + id.mid(3) + "/description")));
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation] {
        reply->deleteLater(); if (generation != m_projectGeneration) return;
        if (reply->error() == QNetworkReply::NoError) {
            QTextDocument description;
            description.setHtml(QJsonDocument::fromJson(reply->readAll()).object().value("data").toString());
            m_project.insert("body", description.toPlainText()); m_project.insert("plainText", true);
        }
        emit changed();
    });
}
