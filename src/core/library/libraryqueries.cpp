#include "instancemodel.h"
#include "displayformat.h"
#include "../prism/accountreader.h"
#include "../prism/paths.h"
#include "../mods/contentart.h"
#include <QDir>
#include <QFileInfo>
#include <QUrl>

QVariantMap InstanceModel::getById(const QString &id) const
{
    const Instance *inst = find(id);
    if (!inst) return {};
    return {{"instanceId", inst->id}, {"name", inst->name}, {"icon", inst->iconUrl},
            {"version", inst->mcVersion}, {"loader", inst->loader}, {"loaderVersion", inst->loaderVersion},
            {"accountId", inst->accountId}, {"mods", inst->mods}, {"memory", inst->memory}, {"played", Library::formatPlayed(inst->playedSecs)},
            {"lastPlayed", Library::formatLastPlayed(inst->lastLaunchMs)}, {"screenshot", inst->screenshotUrl},
            {"lastLaunchMs", inst->lastLaunchMs}, {"playedSecs", inst->playedSecs},
            {"altOf", inst->altOf}, {"altAccount", inst->altAccount}};
}

QVariantList InstanceModel::allInstances() const
{
    QVariantList result;
    for (const Instance &inst : m_all) if (inst.altOf.isEmpty()) result.append(getById(inst.id));
    return result;
}

QVariantList InstanceModel::copies() const
{
    QVariantList result;
    for (const Instance &inst : m_all) if (!inst.altOf.isEmpty()) result.append(getById(inst.id));
    return result;
}

QVariantMap InstanceModel::summary() const
{
    qint64 played = 0;
    int mods = 0;
    const Instance *mostPlayed = nullptr;
    for (const Instance &inst : m_all) {
        if (!inst.altOf.isEmpty()) continue;
        played += inst.playedSecs;
        mods += inst.mods;
        if (!mostPlayed || inst.playedSecs > mostPlayed->playedSecs) mostPlayed = &inst;
    }
    return {{"totalPlayed", Library::formatPlayed(played)}, {"totalMods", mods}, {"instanceCount", totalCount()},
            {"mostPlayed", mostPlayed && mostPlayed->playedSecs > 0 ? mostPlayed->name : QStringLiteral("—")}};
}

QVariantList InstanceModel::accounts() const { return Prism::readAccounts(m_dataDir); }

QString InstanceModel::instancePath(const QString &id) const
{
    const Instance *inst = find(id);
    return inst ? inst->path : QString();
}

QVariantList InstanceModel::worlds() const
{
    QVariantList result;
    for (const auto &inst : m_all) {
        if (!inst.altOf.isEmpty()) continue;
        for (const auto &world : QDir(Prism::gameDir(inst.path) + "/saves").entryInfoList(QDir::Dirs | QDir::NoDotAndDotDot, QDir::Time)) {
            if (QFileInfo::exists(world.absoluteFilePath() + "/level.dat"))
                result.append(QVariantMap{{"name", world.fileName()}, {"instanceId", inst.id}, {"instanceName", inst.name},
                    {"icon", ContentArt::fromFolder(world.absoluteFilePath(), {"icon.png"})}});
        }
    }
    return result;
}


QVariantList InstanceModel::screenshots(const QString &id, int limit) const
{
    QVariantList result;
    const Instance *inst = find(id);
    if (!inst) return result;
    const auto files = QDir(Prism::gameDir(inst->path) + "/screenshots").entryInfoList({"*.png", "*.jpg", "*.jpeg"}, QDir::Files | QDir::NoSymLinks, QDir::Time);
    for (const auto &file : files) {
        if (result.size() >= limit) break;
        result.append(QVariantMap{{"url", QUrl::fromLocalFile(file.absoluteFilePath()).toString()}, {"fileName", file.fileName()}});
    }
    return result;
}
