#pragma once
#include <QObject>
#include <QVariantList>
#include <QVariantMap>
#include "../library/instancemodel.h"

// Measures disk use per instance and for Prism's shared folders, and removes
// only regenerable or explicitly chosen data. Scans run off the UI thread.
class StorageManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QVariantList instances READ instances NOTIFY changed)
    Q_PROPERTY(QVariantList shared READ shared NOTIFY changed)
    Q_PROPERTY(double total READ total NOTIFY changed)
    Q_PROPERTY(double diskFree READ diskFree NOTIFY changed)
    Q_PROPERTY(double diskSize READ diskSize NOTIFY changed)
    // {checking, checked, duplicates, savings, sharedFiles, saved}
    Q_PROPERTY(QVariantMap sharing READ sharing NOTIFY changed)
public:
    explicit StorageManager(InstanceModel *model, QObject *parent = nullptr);
    bool loading() const { return m_loading; }
    QVariantList instances() const { return m_instances; }
    QVariantList shared() const { return m_shared; }
    double total() const { return m_total; }
    double diskFree() const { return m_diskFree; }
    double diskSize() const { return m_diskSize; }
    QVariantMap sharing() const { return m_sharing; }
    Q_INVOKABLE void scan();
    // Categories: "logs", "caches", "removed", "backups" are deleted; "screenshots" go to the trash.
    Q_INVOKABLE double clean(const QString &instanceId, const QStringList &categories);
    Q_INVOKABLE bool trashWorld(const QString &instanceId, const QString &world);
    // Prism's download cache; refused while Prism is open.
    Q_INVOKABLE double clearLauncherCache();
    // Shared content (optional): hard-link identical mods/packs across idle instances.
    Q_INVOKABLE void findDuplicates();
    Q_INVOKABLE QVariantMap shareDuplicates();
    Q_INVOKABLE int unshareAll();
    static QStringList sharedContentFiles(const QStringList &instancePaths);
    static QVector<QStringList> duplicateGroups(const QStringList &files);
    static QVariantMap linkGroups(const QVector<QStringList> &groups);
    static int unshareFiles(const QStringList &files);
    static QVariantMap sharingSummary(const QStringList &files);

    struct Category { QString key, label; QStringList paths; bool cleanable = false; };
    // Folder layout for one instance, relative to nothing: absolute paths.
    static QVector<Category> categories(const QString &instancePath);
    static qint64 folderSize(const QString &path);
    static QVariantMap measureInstance(const QString &id, const QString &name, const QString &path);
signals:
    void changed();
    void errorOccurred(const QString &message);
    void notice(const QString &message);
private:
    void replaceInstance(const QVariantMap &entry);
    QStringList idleInstancePaths() const;
    void updateTotals();
    InstanceModel *m_model;
    QVariantList m_instances, m_shared;
    QVariantMap m_sharing;
    double m_total = 0, m_diskFree = 0, m_diskSize = 0;
    bool m_loading = false;
    quint64 m_generation = 0;
};
