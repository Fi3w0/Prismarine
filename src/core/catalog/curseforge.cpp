#include "curseforge.h"
#include <QJsonArray>
#include <QMap>

int CurseForge::loaderId(const QString &loader) { return QMap<QString, int>{{"forge", 1}, {"fabric", 4}, {"quilt", 5}, {"neoforge", 6}}.value(loader.toLower()); }
QJsonObject CurseForge::version(const QJsonObject &file)
{
    const QString id = "cf:" + QString::number(file.value("id").toInteger()), project = "cf:" + QString::number(file.value("modId").toInteger());
    QJsonObject hashes; QJsonArray loaders, dependencies;
    for (const auto &value : file.value("hashes").toArray()) {
        const auto h = value.toObject(); if (h.value("algo").toInt() == 1) hashes.insert("sha1", h.value("value"));
    }
    for (const auto &value : file.value("gameVersions").toArray()) {
        const auto label = value.toString().toLower(); if (loaderId(label)) loaders.append(label);
    }
    for (const auto &value : file.value("dependencies").toArray()) {
        const auto dep = value.toObject(); const int relation = dep.value("relationType").toInt();
        if (relation == 3 || relation == 5) dependencies.append(QJsonObject{{"project_id", "cf:" + QString::number(dep.value("modId").toInteger())},
            {"dependency_type", relation == 3 ? "required" : "incompatible"}});
    }
    const QString type = file.value("releaseType").toInt() == 1 ? "release" : file.value("releaseType").toInt() == 2 ? "beta" : "alpha";
    return {{"id", id}, {"project_id", project}, {"provider", "curseforge"}, {"name", file.value("displayName")},
        {"version_number", file.value("displayName")}, {"version_type", type}, {"date_published", file.value("fileDate")},
        {"game_versions", file.value("gameVersions")}, {"loaders", loaders}, {"dependencies", dependencies},
        {"files", QJsonArray{QJsonObject{{"primary", true}, {"filename", file.value("fileName")}, {"size", file.value("fileLength")},
            {"url", file.value("downloadUrl")}, {"hashes", hashes}}}}};
}
quint32 CurseForge::fingerprint(const QByteArray &bytes)
{
    QByteArray data; data.reserve(bytes.size());
    for (const auto c : bytes) if (c != 9 && c != 10 && c != 13 && c != 32) data.append(c);
    constexpr quint32 m = 0x5bd1e995; quint32 h = 1 ^ quint32(data.size());
    const auto *p = reinterpret_cast<const unsigned char *>(data.constData()); qsizetype left = data.size();
    while (left >= 4) {
        quint32 k = quint32(p[0]) | quint32(p[1]) << 8 | quint32(p[2]) << 16 | quint32(p[3]) << 24;
        k *= m; k ^= k >> 24; k *= m; h = (h * m) ^ k; p += 4; left -= 4;
    }
    if (left == 3) h ^= quint32(p[2]) << 16;
    if (left >= 2) h ^= quint32(p[1]) << 8;
    if (left >= 1) { h ^= quint32(p[0]); h *= m; }
    h ^= h >> 13; h *= m; h ^= h >> 15; return h;
}
