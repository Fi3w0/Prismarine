#include "modcatalog.h"
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>

void ModCatalog::loadProject(const QString &id)
{
    const auto generation = ++m_projectGeneration;
    m_project.clear(); emit changed();
    if (m_provider == "curseforge") { curseForgeProject(id, generation); return; }
    auto *reply = m_network.get(request(QUrl(m_apiRoot.toString() + "/project/" + QString::fromUtf8(QUrl::toPercentEncoding(id)))));
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation] {
        if (generation == m_projectGeneration) {
            if (reply->error() == QNetworkReply::NoError) m_project = QJsonDocument::fromJson(reply->readAll()).object().toVariantMap();
            emit changed();
        }
        reply->deleteLater();
    });
}
