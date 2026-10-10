#include "instancemodel.h"
#include "displayformat.h"
#include "../prism/configreader.h"
#include "../prism/paths.h"
#include "../prism/instancereader.h"
#include <QDir>
#include <algorithm>

InstanceModel::InstanceModel(QObject *parent, const QString &dataDir)
    : QAbstractListModel(parent)
    , m_dataDir(dataDir.isEmpty() ? Prism::findDataDir() : QDir(dataDir).absolutePath())
{
    m_refreshTimer.setInterval(400);
    m_refreshTimer.setSingleShot(true);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_refreshTimer.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_refreshTimer.start(); });
    connect(&m_refreshTimer, &QTimer::timeout, this, &InstanceModel::reload);
    reload();
}

void InstanceModel::reload()
{
    m_refreshTimer.stop();
    const auto global = Prism::readConfig(m_dataDir + "/prismlauncher.cfg");
    QString dir = global.value("InstanceDir", "instances");
    if (QDir::isRelativePath(dir)) dir = m_dataDir + "/" + dir;
    m_instanceDir = QDir::cleanPath(dir);
    QStringList watched{m_dataDir, m_instanceDir, m_instanceDir + "/instgroups.json", m_dataDir + "/prismlauncher.cfg", m_dataDir + "/accounts.json", m_dataDir + "/icons"};
    const auto found = Prism::readInstances(m_dataDir, m_instanceDir, global);
    for (const auto &inst : found) {
        const QString game = Prism::gameDir(inst.path);
        watched << inst.path << inst.path + "/instance.cfg" << inst.path + "/mmc-pack.json"
                << game << game + "/mods" << game + "/screenshots" << game + "/saves";
    }
    beginResetModel();
    m_all = found;
    applyFilter();
    endResetModel();
    if (!m_watcher.directories().isEmpty()) m_watcher.removePaths(m_watcher.directories());
    if (!m_watcher.files().isEmpty()) m_watcher.removePaths(m_watcher.files());
    watched.removeDuplicates();
    for (const auto &path : watched) if (QFileInfo::exists(path)) m_watcher.addPath(path);
    emit countChanged();
}

void InstanceModel::setFilter(const QString &text, const QString &loader)
{
    beginResetModel();
    m_filterText = text.trimmed();
    m_filterLoader = loader;
    applyFilter();
    endResetModel();
    emit countChanged();
}

void InstanceModel::applyFilter()
{
    m_visible.clear();
    for (int i = 0; i < m_all.size(); ++i) {
        const Instance &inst = m_all.at(i);
        // Multi-account copies are reached from their source instance, not the library.
        if (!inst.altOf.isEmpty())
            continue;
        if (!m_filterLoader.isEmpty() && inst.loader != m_filterLoader)
            continue;
        if (!m_filterText.isEmpty() && !inst.name.contains(m_filterText, Qt::CaseInsensitive)
            && !inst.mcVersion.contains(m_filterText))
            continue;
        m_visible.append(i);
    }
    std::stable_sort(m_visible.begin(), m_visible.end(), [this](int a, int b) {
        const Instance &left = m_all.at(a);
        const Instance &right = m_all.at(b);
        if (m_sort == "name")
            return left.name.compare(right.name, Qt::CaseInsensitive) < 0;
        if (m_sort == "mods" && left.mods != right.mods)
            return left.mods > right.mods;
        return left.lastLaunchMs > right.lastLaunchMs;
    });
}

void InstanceModel::setSort(const QString &sort)
{
    if (sort == m_sort || (sort != "recent" && sort != "name" && sort != "mods"))
        return;
    beginResetModel();
    m_sort = sort;
    applyFilter();
    endResetModel();
    emit countChanged();
}

int InstanceModel::rowCount(const QModelIndex &parent) const
{
    return parent.isValid() ? 0 : m_visible.size();
}

QVariant InstanceModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() < 0 || index.row() >= m_visible.size())
        return {};
    const Instance &inst = m_all.at(m_visible.at(index.row()));
    switch (role) {
    case InstanceIdRole: return inst.id;
    case NameRole: return inst.name;
    case IconRole: return inst.iconUrl;
    case VersionRole: return inst.mcVersion;
    case LoaderRole: return inst.loader;
    case LoaderVersionRole: return inst.loaderVersion;
    case ModsRole: return inst.mods;
    case PlayedRole: return Library::formatPlayed(inst.playedSecs);
    case LastPlayedRole: return Library::formatLastPlayed(inst.lastLaunchMs);
    case ScreenshotRole: return inst.screenshotUrl;
    }
    return {};
}

QHash<int, QByteArray> InstanceModel::roleNames() const
{
    return {
        {InstanceIdRole, "instanceId"},
        {NameRole, "name"},
        {IconRole, "icon"},
        {VersionRole, "version"},
        {LoaderRole, "loader"},
        {LoaderVersionRole, "loaderVersion"},
        {ModsRole, "mods"},
        {PlayedRole, "played"},
        {LastPlayedRole, "lastPlayed"},
        {ScreenshotRole, "screenshot"},
    };
}

QVariantMap InstanceModel::get(int row) const
{
    QVariantMap map;
    if (row < 0 || row >= m_visible.size())
        return map;
    const QModelIndex idx = index(row);
    const auto roles = roleNames();
    for (auto it = roles.cbegin(); it != roles.cend(); ++it)
        map.insert(QString::fromUtf8(it.value()), data(idx, it.key()));
    map.insert("accountId", m_all.at(m_visible.at(row)).accountId);
    map.insert("memory", m_all.at(m_visible.at(row)).memory);
    return map;
}

QStringList InstanceModel::loaders() const
{
    QStringList result;
    for (const Instance &inst : m_all) {
        if (!result.contains(inst.loader))
            result.append(inst.loader);
    }
    std::sort(result.begin(), result.end());
    return result;
}

int InstanceModel::loaderCount(const QString &loader) const
{
    return std::count_if(m_all.cbegin(), m_all.cend(), [&loader](const Instance &inst) {
        return inst.loader == loader;
    });
}

const Instance *InstanceModel::find(const QString &instanceId) const
{
    for (const Instance &inst : m_all) {
        if (inst.id == instanceId)
            return &inst;
    }
    return nullptr;
}

