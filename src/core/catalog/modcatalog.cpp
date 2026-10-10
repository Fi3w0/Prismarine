#include "modcatalog.h"
#include <QNetworkReply>
#include <QUrlQuery>
#include <QJsonDocument>
#include <QJsonArray>
#include <QJsonObject>

ModCatalog::ModCatalog(QObject *parent, const QUrl &apiRoot, const QUrl &curseApi)
    : QObject(parent), m_apiRoot(apiRoot), m_curseApi(curseApi), m_curseKey(qgetenv("PRISMARINE_CURSEFORGE_API_KEY")) {}
QNetworkRequest ModCatalog::request(const QUrl &url) const
{
    QNetworkRequest req(url);
    req.setRawHeader("User-Agent", "Prismarine/0.4.0 (Qt desktop UI)");
    req.setRawHeader("Accept", "application/json");
    req.setTransferTimeout(15000);
    return req;
}
void ModCatalog::search(const QString &query, const QString &version, const QString &loader, const QString &type,
                        const QStringList &categories)
{
    const quint64 generation = ++m_searchGeneration;
    ++m_versionGeneration;
    ++m_projectGeneration;
    m_project.clear();
    m_loading = true;
    m_versionsLoading = false;
    m_error.clear();
    m_results.clear();
    m_versions.clear();
    emit changed();
    if (m_provider == "curseforge") { searchCurseForge(query, version, loader, type, generation); return; }
    QJsonArray facets{QJsonArray{QStringLiteral("project_type:") + (type == "shader" || type == "resourcepack" || type == "modpack" ? type : "mod")}};
    if (type == "datapack") facets = QJsonArray{QJsonArray{"all_project_types:datapack"}};
    if (!version.isEmpty()) facets.append(QJsonArray{QStringLiteral("versions:") + version});
    const QString normalized = loader.toLower();
    if (type == "mod" && QStringList{"fabric", "forge", "neoforge", "quilt"}.contains(normalized))
        facets.append(QJsonArray{QStringLiteral("categories:") + normalized});
    // Facets in one inner array are OR'd: a project matching any chosen category is shown.
    QJsonArray anyCategory;
    for (const QString &category : categories)
        anyCategory.append(QStringLiteral("categories:") + category);
    if (!anyCategory.isEmpty()) facets.append(anyCategory);
    QUrl url(m_apiRoot.toString() + "/search");
    QUrlQuery params;
    params.addQueryItem("query", query);
    params.addQueryItem("limit", "40");
    params.addQueryItem("facets", QString::fromUtf8(QJsonDocument(facets).toJson(QJsonDocument::Compact)));
    url.setQuery(params);
    auto *reply = m_network.get(request(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation] {
        if (generation == m_searchGeneration) {
            m_loading = false;
            if (reply->error() != QNetworkReply::NoError) m_error = "Could not reach Modrinth. " + reply->errorString();
            else {
                QJsonParseError error;
                const auto doc = QJsonDocument::fromJson(reply->readAll(), &error);
                if (error.error != QJsonParseError::NoError || !doc.isObject()) m_error = "Modrinth returned an unreadable response.";
                else m_results = doc.object().value("hits").toArray().toVariantList();
            }
            emit changed();
        }
        reply->deleteLater();
    });
}
void ModCatalog::loadCategories()
{
    if (m_categoriesRequested) return;
    m_categoriesRequested = true;
    auto *reply = m_network.get(request(QUrl(m_apiRoot.toString() + "/tag/category")));
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        const auto doc = QJsonDocument::fromJson(reply->readAll());
        if (reply->error() != QNetworkReply::NoError || !doc.isArray()) m_categoriesRequested = false;
        else {
            m_categoryTags = doc.array().toVariantList();
            emit categoriesChanged();
        }
        reply->deleteLater();
    });
}
QStringList ModCatalog::categoriesFor(const QString &type) const
{
    if (m_provider == "curseforge") return {};
    const QString projectType = type == "shader" || type == "resourcepack" || type == "modpack" ? type : "mod";
    QStringList names;
    for (const QVariant &value : m_categoryTags) {
        const QVariantMap tag = value.toMap();
        // Resolution and performance tags are pack attributes rather than subject categories.
        if (tag.value("project_type") == projectType && tag.value("header") == "categories")
            names.append(tag.value("name").toString());
    }
    names.sort();
    return names;
}
void ModCatalog::loadVersions(const QString &id, const QString &version, const QString &loader)
{
    const quint64 generation = ++m_versionGeneration;
    m_versions.clear();
    m_error.clear();
    m_versionsLoading = true;
    emit changed();
    if (m_provider == "curseforge") { curseForgeVersions(id, version, loader, generation); return; }
    QUrl url(m_apiRoot.toString() + "/project/" + QString::fromUtf8(QUrl::toPercentEncoding(id)) + "/version");
    QUrlQuery params;
    if (!version.isEmpty()) params.addQueryItem("game_versions", QString::fromUtf8(QJsonDocument(QJsonArray{version}).toJson(QJsonDocument::Compact)));
    if (QStringList{"fabric", "forge", "neoforge", "quilt", "datapack"}.contains(loader.toLower()))
        params.addQueryItem("loaders", QString::fromUtf8(QJsonDocument(QJsonArray{loader.toLower()}).toJson(QJsonDocument::Compact)));
    url.setQuery(params);
    auto *reply = m_network.get(request(url));
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation] {
        if (generation == m_versionGeneration) {
            m_versionsLoading = false;
            if (reply->error() != QNetworkReply::NoError) m_error = "Could not load project versions. " + reply->errorString();
            else {
                QJsonParseError error;
                const auto doc = QJsonDocument::fromJson(reply->readAll(), &error);
                if (error.error != QJsonParseError::NoError || !doc.isArray()) m_error = "Modrinth returned an unreadable response.";
                else m_versions = doc.array().toVariantList();
            }
            emit changed();
        }
        reply->deleteLater();
    });
}
