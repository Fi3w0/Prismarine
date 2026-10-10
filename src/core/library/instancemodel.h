#pragma once

#include <QAbstractListModel>
#include <QString>
#include <QStringList>
#include <QVariantMap>
#include <QVector>
#include "instance.h"
#include <QUrl>
#include <QFileSystemWatcher>
#include <QTimer>
#include <QJsonObject>
#include <functional>
#include <algorithm>

class InstanceModel : public QAbstractListModel
{
    Q_OBJECT
    Q_PROPERTY(int count READ count NOTIFY countChanged)
    Q_PROPERTY(int totalCount READ totalCount NOTIFY countChanged)
    Q_PROPERTY(QStringList availableLoaders READ loaders NOTIFY countChanged)
    Q_PROPERTY(QString instanceDir READ instanceDir NOTIFY countChanged)
    Q_PROPERTY(QString dataDir READ dataDir CONSTANT)
    Q_PROPERTY(QVariantList allInstances READ allInstances NOTIFY countChanged)
    Q_PROPERTY(QVariantMap summary READ summary NOTIFY countChanged)
    Q_PROPERTY(QVariantList groups READ groups NOTIFY countChanged)
    Q_PROPERTY(QVariantList accounts READ accounts NOTIFY countChanged)
    Q_PROPERTY(QVariantList worlds READ worlds NOTIFY countChanged)

public:
    enum Role {
        InstanceIdRole = Qt::UserRole + 1,
        NameRole,
        IconRole,
        VersionRole,
        LoaderRole,
        LoaderVersionRole,
        ModsRole,
        PlayedRole,
        LastPlayedRole,
        ScreenshotRole,
    };

    explicit InstanceModel(QObject *parent = nullptr, const QString &dataDir = {});

    int rowCount(const QModelIndex &parent = {}) const override;
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;

    int count() const { return m_visible.size(); }
    int totalCount() const { return std::count_if(m_all.cbegin(), m_all.cend(), [](const Instance &it) { return it.altOf.isEmpty(); }); }
    QString instanceDir() const { return m_instanceDir; }
    QString dataDir() const { return m_dataDir; }
    // Regular instances only; multi-account copies are listed by copies().
    QVariantList allInstances() const;
    Q_INVOKABLE QVariantList copies() const;
    // Newest screenshots of one instance: [{url, fileName}].
    Q_INVOKABLE QVariantList screenshots(const QString &instanceId, int limit = 24) const;
    QVariantMap summary() const;
    QVariantList groups() const;
    QVariantList accounts() const;
    QVariantList worlds() const;
    QString instancePath(const QString &id) const;

    Q_INVOKABLE void reload();
    Q_INVOKABLE void setFilter(const QString &text, const QString &loader);
    Q_INVOKABLE QVariantMap get(int row) const;
    Q_INVOKABLE QVariantMap getById(const QString &id) const;
    Q_INVOKABLE QStringList loaders() const;
    Q_INVOKABLE int loaderCount(const QString &loader) const;
    Q_INVOKABLE void setSort(const QString &sort);
    Q_INVOKABLE bool launch(const QString &instanceId);
    Q_INVOKABLE bool renameInstance(const QString &instanceId, const QString &name, const QString &originalName);
    Q_INVOKABLE bool openFolder(const QString &instanceId);
    Q_INVOKABLE bool openPrism();
    Q_INVOKABLE bool editInPrism(const QString &instanceId);
    Q_INVOKABLE bool openModsFolder(const QString &instanceId);
    Q_INVOKABLE bool launchWorld(const QString &instanceId, const QString &world);
    Q_INVOKABLE bool launchServer(const QString &instanceId, const QString &address);
    Q_INVOKABLE bool importPack(const QUrl &url);
    // Groups live in Prism's instgroups.json; folder IDs never change.
    Q_INVOKABLE QStringList groupNames() const;
    Q_INVOKABLE QString groupOf(const QString &instanceId) const;
    Q_INVOKABLE bool createGroup(const QString &name);
    Q_INVOKABLE bool renameGroup(const QString &name, const QString &newName);
    Q_INVOKABLE bool deleteGroup(const QString &name);
    Q_INVOKABLE bool moveToGroup(const QString &instanceId, const QString &group);
    Q_INVOKABLE bool setGroupCollapsed(const QString &name, bool collapsed);
    Q_INVOKABLE bool prismRunning() const;
    // Whether this instance's game is running (Linux: found through /proc).
    Q_INVOKABLE bool isRunning(const QString &instanceId) const;
    // Prism's console window (ShowConsole / ShowConsoleOnError in prismlauncher.cfg).
    // Prismarine has its own log and crash help, so by default Prism keeps it closed.
    Q_INVOKABLE bool setPrismConsole(bool allow);
    // Which Prism program launches use; empty = automatic. See Prism::launcherProgram.
    Q_INVOKABLE void setPrismProgram(const QString &path);
    Q_INVOKABLE QString prismProgram() const;
    // Adds an instance to a group, creating the group when needed.
    bool moveToGroupQuietly(const QString &instanceId, const QString &group);

signals:
    void countChanged();
    void errorOccurred(const QString &message);

private:
    void applyFilter();
    const Instance *find(const QString &instanceId) const;
    bool startPrism(const QStringList &arguments);
    bool refuseIfRunning(const Instance &inst);
    bool editGroups(const std::function<QString(QJsonObject &)> &change);

    QString m_dataDir;
    QString m_instanceDir;
    QString m_filterText;
    QString m_filterLoader;
    QString m_sort = "recent";
    QVector<Instance> m_all;
    QVector<int> m_visible;
    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer;
};
