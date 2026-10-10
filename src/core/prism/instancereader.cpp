#include "instancereader.h"
#include "configreader.h"
#include "paths.h"
#include <QDir>
#include <QRegularExpression>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QUrl>
#include <algorithm>

namespace {
QString loaderName(const QString &uid)
{
    if (uid == "net.neoforged")
        return "NeoForge";
    if (uid == "net.minecraftforge")
        return "Forge";
    if (uid == "net.fabricmc.fabric-loader")
        return "Fabric";
    if (uid == "org.quiltmc.quilt-loader")
        return "Quilt";
    return {};
}

}

QVector<Instance> Prism::readInstances(const QString &dataDir, const QString &instanceDir, const QHash<QString, QString> &global)
{
    QVector<Instance> found;
    const QDir icons(dataDir + "/icons");
    const QFileInfoList iconFiles = icons.entryInfoList(QDir::Files);

    const QFileInfoList dirs = QDir(instanceDir).entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot);
    for (const QFileInfo &dirInfo : dirs) {
        const QString path = dirInfo.absoluteFilePath();
        const auto cfg = Prism::readConfig(path + "/instance.cfg");
        if (cfg.isEmpty())
            continue;

        Instance inst;
        inst.id = dirInfo.fileName();
        inst.path = path;
        inst.name = cfg.value("name", inst.id);
        inst.playedSecs = cfg.value("totalTimePlayed").toLongLong();
        inst.lastLaunchMs = cfg.value("lastLaunchTime").toLongLong();
        inst.loader = QStringLiteral("Vanilla");
        const bool memoryOverride = cfg.value("OverrideMemory").compare("true", Qt::CaseInsensitive) == 0;
        const int memory = (memoryOverride ? cfg : global).value("MaxMemAlloc").toInt();
        inst.accountId = cfg.value("UseAccountForInstance") == "true" ? cfg.value("InstanceAccountId") : "";
        inst.memory = memory > 0 ? QString::number(memory / 1024.0, 'f', 1).remove(QRegularExpression("\\.0$")) + " GiB" : "Prism default";

        if (QFile marker(path + "/.prismarine-alt.json"); marker.open(QIODevice::ReadOnly)) {
            const auto alt = QJsonDocument::fromJson(marker.readAll()).object();
            inst.altOf = alt.value("source").toString();
            inst.altAccount = alt.value("account").toString();
        }

        const QString iconKey = cfg.value("iconKey");
        for (const QFileInfo &icon : iconFiles) {
            if (icon.completeBaseName() == iconKey) {
                inst.iconUrl = QUrl::fromLocalFile(icon.absoluteFilePath()).toString();
                break;
            }
        }

        QFile pack(path + "/mmc-pack.json");
        if (pack.open(QIODevice::ReadOnly)) {
            const QJsonArray components = QJsonDocument::fromJson(pack.readAll()).object().value("components").toArray();
            for (const QJsonValue &value : components) {
                const QJsonObject c = value.toObject();
                const QString uid = c.value("uid").toString();
                const QString version = c.value("version").toString();
                if (uid == "net.minecraft") {
                    inst.mcVersion = version;
                } else if (const QString name = loaderName(uid); !name.isEmpty()) {
                    inst.loader = name;
                    inst.loaderVersion = version;
                }
            }
        }

        const QString game = Prism::gameDir(path);
        inst.mods = QDir(game + "/mods").entryList({"*.jar"}, QDir::Files).size();
        const QFileInfoList shots = QDir(game + "/screenshots")
                                        .entryInfoList({"*.png", "*.jpg", "*.jpeg", "*.webp"}, QDir::Files, QDir::Time);
        if (!shots.isEmpty())
            inst.screenshotUrl = QUrl::fromLocalFile(shots.first().absoluteFilePath()).toString();

        found.append(inst);
    }

    // Most recently played first, never-played instances last.
    std::sort(found.begin(), found.end(), [](const Instance &a, const Instance &b) {
        if (a.lastLaunchMs != b.lastLaunchMs)
            return a.lastLaunchMs > b.lastLaunchMs;
        return a.name.compare(b.name, Qt::CaseInsensitive) < 0;
    });

    return found;
}
