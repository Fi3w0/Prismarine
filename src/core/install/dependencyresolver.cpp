#include "contentinstaller.h"
#include "../prism/paths.h"
#include <QJsonDocument>
#include <QJsonArray>
#include <QUrlQuery>
#include <QDir>
#include <QFileInfo>
#include <QRegularExpression>

ContentInstaller::ContentInstaller(InstanceModel *model, QObject *parent, const QUrl &apiRoot, const QUrl &curseApi)
    : QObject(parent), m_model(model), m_apiRoot(apiRoot), m_curseApi(curseApi) {}
void ContentInstaller::cancel()
{
    ++m_generation;
    if (m_reply) m_reply->abort();
    m_reply.clear(); m_staging.reset(); m_plan.clear(); m_pending.clear(); m_incompatible.clear(); m_seen.clear(); m_projects.clear(); m_requested.clear(); m_installedProjects.clear();
    m_state = "idle"; m_error.clear(); m_progress = 0; emit changed();
}
void ContentInstaller::fail(const QString &error)
{
    m_state = "error"; m_error = error; m_staging.reset(); emit changed();
}
void ContentInstaller::prepare(const QString &id, const QVariantMap &version, const QString &type, const QString &world)
{
    prepareMany(id, {version}, type, world);
}
void ContentInstaller::prepareMany(const QString &id, const QVariantList &versions, const QString &type, const QString &world)
{
    cancel();
    if (versions.isEmpty() || versions.size() > 100) { fail("Choose between 1 and 100 projects to install."); return; }
    m_provider = versions.first().toMap().value("provider", "modrinth").toString();
    for (const auto &version : versions) if (version.toMap().value("provider", "modrinth").toString() != m_provider) { fail("Install selections from one provider at a time."); return; }
    if (m_provider == "curseforge" && m_curseKey.isEmpty()) { fail("Add a CurseForge API key before installing."); return; }
    for (const auto &version : versions) m_requested.insert(version.toMap().value("id").toString());
    const auto instance = m_model->getById(id);
    if (instance.isEmpty()) { fail("Select an instance to install into."); return; }
    if (!QStringList{"mod", "resourcepack", "shader", "datapack"}.contains(type)) { fail("Unsupported content type."); return; }
    m_world = world;
    m_id = id; m_type = type; m_gameVersion = instance.value("version").toString();
    m_loader = instance.value("loader").toString().toLower();
    m_target = Prism::contentDir(m_model->instancePath(id), type, world);
    if (m_target.isEmpty()) { fail("Choose a valid content folder or saved world in this instance."); return; }
    m_state = "resolving";
    emit changed();
    if (m_provider == "curseforge") indexCurseForge(QJsonArray::fromVariantList(versions));
    else indexInstalled(QJsonArray::fromVariantList(versions));
}
void ContentInstaller::getJson(const QUrl &url, std::function<void(const QJsonDocument &)> done)
{
    const auto generation = m_generation;
    QNetworkRequest request(url); request.setTransferTimeout(20000); request.setRawHeader("User-Agent", "Prismarine/0.4.0");
    if (url.toString().startsWith(m_curseApi.toString() + "/")) {
        request.setRawHeader("x-api-key", m_curseKey);
        request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    }
    auto *reply = m_network.get(request); m_reply = reply;
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation, done] {
        if (generation == m_generation && m_state == "resolving") {
            QJsonParseError error;
            const auto doc = QJsonDocument::fromJson(reply->readAll(), &error);
            if (reply->error() != QNetworkReply::NoError || error.error != QJsonParseError::NoError)
                fail("Could not resolve a required dependency. " + reply->errorString());
            else done(doc);
        }
        reply->deleteLater();
    });
}
bool ContentInstaller::appendVersion(const QJsonObject &v)
{
    const QString id = v.value("id").toString(), project = v.value("project_id").toString();
    if (id.isEmpty() || project.isEmpty()) { fail("This version has no project identifier."); return false; }
    if (m_seen.contains(id)) return true;
    for (const auto &conflict : m_incompatible) {
        const QString conflictProject = conflict.value("project_id").toString(), conflictVersion = conflict.value("version_id").toString();
        if ((!conflictVersion.isEmpty() && conflictVersion == id) || (conflictVersion.isEmpty() && conflictProject == project)) {
            fail("Two selected projects declare incompatible versions."); return false;
        }
    }
    if (m_installedProjects.contains(project) && m_installedProjects.value(project) != id) {
        fail("Another version of this project is already installed. Remove the old version before installing this one."); return false;
    }
    if (m_seen.size() >= 100 || m_projects.contains(project)) { fail("The dependency plan contains conflicting versions."); return false; }
    if (!v.value("game_versions").toArray().contains(m_gameVersion)
        || (m_type == "mod" && !v.value("loaders").toArray().contains(m_loader))
        || (m_type == "datapack" && !v.value("loaders").toArray().contains("datapack"))) {
        fail("A selected version or dependency is incompatible with this instance."); return false;
    }
    QJsonObject file;
    for (const auto &value : v.value("files").toArray()) {
        const auto candidate = value.toObject();
        if (!candidate.value("filename").toString().endsWith(m_type == "mod" ? ".jar" : ".zip", Qt::CaseInsensitive)) continue;
        if (file.isEmpty() || candidate.value("primary").toBool()) file = candidate;
        if (candidate.value("primary").toBool()) break;
    }
    const QString name = file.value("filename").toString();
    const auto hashes = file.value("hashes").toObject();
    const QString algorithm = m_provider == "curseforge" ? "sha1" : "sha512";
    const QString hash = hashes.value(algorithm).toString();
    const QUrl url(file.value("url").toString());
    if (m_provider == "curseforge" && url.isEmpty()) { fail("CurseForge requires a website download for " + v.value("name").toString() + ". Add that file locally, then retry."); return false; }
    if (name.isEmpty() || name.startsWith('.') || name.contains(QRegularExpression("[/\\\\\\x{0000}-\\x{001f}]"))
        || !url.isValid() || (url.scheme() != "https" && !((m_provider == "curseforge" ? m_curseApi : m_apiRoot).scheme() == "http" && url.scheme() == "http"))
        || !QRegularExpression(algorithm == "sha1" ? "^[a-fA-F0-9]{40}$" : "^[a-fA-F0-9]{128}$").match(hash).hasMatch()
        || (m_type == "mod" && !name.endsWith(".jar", Qt::CaseInsensitive))
        || (m_type != "mod" && !name.endsWith(".zip", Qt::CaseInsensitive))) {
        fail("The download has an invalid file name, URL, or verification hash."); return false;
    }
    for (const auto &planned : m_plan) if (planned.toMap().value("filename") == name) { fail("Two downloads use the same file name."); return false; }
    m_seen.insert(id); m_projects.insert(project);
    m_plan.append(QVariantMap{{"name", v.value("name").toString()}, {"filename", name}, {"url", url}, {"hash", hash.toLower()}, {"algorithm", algorithm}, {"sha512", algorithm == "sha512" ? hash.toLower() : QString()},
        {"dependency", !m_requested.contains(id)}, {"size", file.value("size").toInteger()}});
    for (const auto &d : v.value("dependencies").toArray()) {
        const auto dependency = d.toObject();
        if (dependency.value("dependency_type") == "required") m_pending.append(dependency);
        if (dependency.value("dependency_type") == "incompatible") {
            const QString conflictProject = dependency.value("project_id").toString(), conflictVersion = dependency.value("version_id").toString();
            const bool installed = conflictVersion.isEmpty() ? m_installedProjects.contains(conflictProject) : m_installedProjects.values().contains(conflictVersion);
            const bool planned = conflictVersion.isEmpty() ? m_projects.contains(conflictProject) : m_seen.contains(conflictVersion);
            if (installed || planned) { fail("This version conflicts with an installed or selected project."); return false; }
            m_incompatible.append(dependency);
        }
    }
    emit changed(); return true;
}
void ContentInstaller::resolveNext()
{
    if (m_pending.isEmpty()) { m_state = "ready"; emit changed(); return; }
    const auto dependency = m_pending.takeFirst();
    const QString version = dependency.value("version_id").toString(), project = dependency.value("project_id").toString();
    if (m_seen.contains(version)) { resolveNext(); return; }
    if (m_provider == "curseforge") { resolveCurseForge(dependency); return; }
    QUrl url;
    if (!version.isEmpty()) url = QUrl(m_apiRoot.toString() + "/version/" + QString::fromUtf8(QUrl::toPercentEncoding(version)));
    else if (!project.isEmpty()) {
        if (m_projects.contains(project)) { resolveNext(); return; }
        url = QUrl(m_apiRoot.toString() + "/project/" + QString::fromUtf8(QUrl::toPercentEncoding(project)) + "/version");
        QUrlQuery query;
        query.addQueryItem("game_versions", QString::fromUtf8(QJsonDocument(QJsonArray{m_gameVersion}).toJson(QJsonDocument::Compact)));
        if (m_type == "datapack") query.addQueryItem("loaders", "[\"datapack\"]");
        if (m_type == "mod") query.addQueryItem("loaders", QString::fromUtf8(QJsonDocument(QJsonArray{m_loader}).toJson(QJsonDocument::Compact)));
        url.setQuery(query);
    } else { fail("A required dependency does not identify a downloadable project."); return; }
    getJson(url, [this](const QJsonDocument &doc) {
        const auto version = doc.isArray() ? (doc.array().isEmpty() ? QJsonObject() : doc.array().first().toObject()) : doc.object();
        if (appendVersion(version)) resolveNext();
    });
}
