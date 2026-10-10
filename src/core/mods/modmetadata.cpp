#include "modmetadata.h"
#include "archivereader.h"
#include "contentart.h"
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QRegularExpression>

namespace {
QString tomlString(const QString &text, const QString &key)
{
    auto match = QRegularExpression("(?m)^\\s*" + QRegularExpression::escape(key) + "\\s*=\\s*[\"']([^\"'\\r\\n]+)[\"']").match(text);
    return match.hasMatch() ? match.captured(1) : QString();
}
}

QVariantMap Mods::readMetadata(const QFileInfo &file)
{
    QString fallback = file.fileName();
    if (fallback.endsWith(".disabled")) fallback.chop(9);
    fallback.chop(4);
    QVariantMap mod{{"fileName", file.fileName()}, {"name", fallback}, {"version", "—"},
                    {"enabled", !file.fileName().endsWith(".disabled")}, {"side", "Unspecified"},
                    {"description", ""}, {"authors", ""}, {"metadata", false}};
    QString iconPath;
    const auto files = Mods::readMetadataFiles(file.absoluteFilePath());
    const auto fabric = QJsonDocument::fromJson(files.value("fabric.mod.json")).object();
    const auto quilt = QJsonDocument::fromJson(files.value("quilt.mod.json")).object().value("quilt_loader").toObject();
    const auto json = fabric.isEmpty() ? quilt : fabric;
    if (!json.isEmpty()) {
        const auto metadata = fabric.isEmpty() ? quilt.value("metadata").toObject() : fabric;
        const auto icon = metadata.value("icon");
        if (icon.isString()) iconPath = icon.toString();
        else {
            const auto sizes = icon.toObject();
            int best = 0;
            for (auto it = sizes.begin(); it != sizes.end(); ++it)
                if (it.key().toInt() > best) { best = it.key().toInt(); iconPath = it.value().toString(); }
        }
        mod["name"] = metadata.value("name").toString(fallback);
        mod["version"] = json.value("version").toString("—");
        mod["description"] = metadata.value("description").toString();
        const QString environment = fabric.value("environment").toString();
        mod["side"] = environment == "client" ? "Client" : environment == "server" ? "Server" : environment == "*" ? "Both" : "Unspecified";
        QStringList authors;
        for (const auto &author : metadata.value("authors").toArray())
            authors.append(author.isString() ? author.toString() : author.toObject().value("name").toString());
        mod["authors"] = authors.join(", ");
        mod["metadata"] = true;
    } else {
        QString toml = QString::fromUtf8(files.value("META-INF/neoforge.mods.toml", files.value("META-INF/mods.toml")));
        iconPath = tomlString(toml, "logoFile");
        if (toml.contains("[[mods]]")) {
            toml = toml.mid(toml.indexOf("[[mods]]") + 8);
            const int next = toml.indexOf("[[");
            if (next >= 0) toml.truncate(next);
            const QString name = tomlString(toml, "displayName");
            QString version = tomlString(toml, "version");
            if (version.contains("${")) {
                auto match = QRegularExpression("(?m)^Implementation-Version: ([^\\r\\n]+)").match(QString::fromUtf8(files.value("META-INF/MANIFEST.MF")));
                version = match.hasMatch() ? match.captured(1) : QString();
            }
            if (!name.isEmpty()) mod["name"] = name;
            if (!version.isEmpty()) mod["version"] = version;
            mod["authors"] = tomlString(toml, "authors");
            mod["description"] = tomlString(toml, "description");
            mod["metadata"] = true;
        }
    }
    mod["icon"] = ContentArt::fromArchive(file.absoluteFilePath(), iconPath.isEmpty()
        ? QStringList{"icon.png", "logo.png", "pack.png"} : QStringList{iconPath, "icon.png", "logo.png"});
    return mod;
}
