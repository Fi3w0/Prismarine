#include "instancecontents.h"
#include "../prism/configreader.h"
#include "../prism/paths.h"
#include "../mods/modmetadata.h"
#include "../mods/contentart.h"
#include <QDir>
#include <QRegularExpression>
#include <QDateTime>
#include <QUrl>
#include <algorithm>

InstanceContents InstanceContent::scan(const QString &path, const QString &dataDir, QVariantMap info)
{
    InstanceContents contents;
    const QString game = Prism::gameDir(path);
    const auto cfg = Prism::readConfig(path + "/instance.cfg");
    const auto global = Prism::readConfig(dataDir + "/prismlauncher.cfg");
    const bool memoryOverride = cfg.value("OverrideMemory").compare("true", Qt::CaseInsensitive) == 0;
    const int maxMemory = (memoryOverride ? cfg : global).value("MaxMemAlloc").toInt();
    info["memory"] = maxMemory > 0 ? QString::number(maxMemory / 1024.0, 'f', 1).remove(QRegularExpression("\\.0$")) + " GiB" : "Prism default";
    const bool javaOverride = cfg.value("OverrideJavaLocation").compare("true", Qt::CaseInsensitive) == 0;
    info["javaPath"] = (javaOverride ? cfg : global).value("JavaPath");
    info["javaAvailable"] = QFileInfo(info.value("javaPath").toString()).isExecutable();
    info["gameMode"] = (cfg.value("OverridePerformance") == "true" ? cfg : global).value("EnableFeralGamemode") == "true";
    info["mangoHud"] = (cfg.value("OverridePerformance") == "true" ? cfg : global).value("EnableMangoHud") == "true";
    info["path"] = path;
    for (const auto &file : QDir(game + "/mods").entryInfoList({"*.jar", "*.jar.disabled"}, QDir::Files))
        contents.mods.append(Mods::readMetadata(file));
    std::sort(contents.mods.begin(), contents.mods.end(), [](const auto &a, const auto &b) {
        return a.toMap().value("name").toString().compare(b.toMap().value("name").toString(), Qt::CaseInsensitive) < 0;
    });
    int unreadable = 0;
    for (const auto &mod : contents.mods) if (!mod.toMap().value("metadata").toBool()) ++unreadable;
    info["unreadableMods"] = unreadable;
    int enabled = 0;
    for (const auto &mod : contents.mods) if (mod.toMap().value("enabled").toBool()) ++enabled;
    info["enabledMods"] = enabled;
    info["disabledMods"] = contents.mods.size() - enabled;
    for (const auto &file : QDir(game + "/screenshots").entryInfoList({"*.png", "*.jpg", "*.jpeg", "*.webp"}, QDir::Files, QDir::Time)) {
        contents.screenshots.append(QVariantMap{{"fileName", file.fileName()}, {"url", QUrl::fromLocalFile(file.absoluteFilePath()).toString()},
                                               {"date", file.lastModified().toString("dd MMM yyyy · HH:mm")}});
    }
    for (const QString &category : {QStringLiteral("resourcepacks"), QStringLiteral("shaderpacks"), QStringLiteral("saves"), QStringLiteral("logs")}) {
        const bool worlds = category == "saves";
        for (const auto &file : QDir(game + "/" + category).entryInfoList(QDir::Files | (category != "logs" ? QDir::Dirs : QDir::Filter(0)) | QDir::NoDotAndDotDot, QDir::Time)) {
            if (worlds && (!file.isDir() || !QFileInfo::exists(file.absoluteFilePath() + "/level.dat"))) continue;
            if (category == "logs" && !file.fileName().endsWith(".log")) continue;
            const QStringList artNames = worlds ? QStringList{"icon.png"} : QStringList{"pack.png", "icon.png", "logo.png"};
            const QString icon = category == "logs" ? QString() : file.isDir()
                ? ContentArt::fromFolder(file.absoluteFilePath(), artNames)
                : ContentArt::fromArchive(file.absoluteFilePath(), artNames);
            contents.files.append(QVariantMap{{"fileName", file.fileName()}, {"category", category}, {"icon", icon},
                                              {"modified", file.lastModified().toString("dd MMM yyyy")},
                                              {"size", file.isDir() ? (worlds ? "World folder" : "Folder") : QString::number(file.size() / 1024.0, 'f', 0) + " KB"}});
        }
    }
    contents.info = info;
    return contents;
}
