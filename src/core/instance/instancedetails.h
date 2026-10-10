#pragma once
#include <QObject>
#include <QVariantMap>
#include <QFileSystemWatcher>
#include <QTimer>
#include "../library/instancemodel.h"
#include "instancecontents.h"
#include <QJsonArray>
#include <functional>

class InstanceDetails : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap info READ info NOTIFY changed)
    Q_PROPERTY(QVariantList mods READ mods NOTIFY changed)
    Q_PROPERTY(QVariantList screenshots READ screenshots NOTIFY changed)
    Q_PROPERTY(QVariantList files READ files NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY changed)
    Q_PROPERTY(QVariantList profiles READ profiles NOTIFY changed)
public:
    explicit InstanceDetails(InstanceModel *model, QObject *parent = nullptr);
    QVariantMap info() const { return m_contents.info; }
    QVariantList mods() const { return m_contents.mods; }
    QVariantList screenshots() const { return m_contents.screenshots; }
    QVariantList files() const { return m_contents.files; }
    bool loading() const { return m_loading; }
    QString instanceId() const { return m_id; }
    Q_INVOKABLE void load(const QString &id);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool setModEnabled(const QString &fileName, bool enabled);
    Q_INVOKABLE int setModsEnabled(const QStringList &fileNames, bool enabled);
    Q_INVOKABLE int removeMods(const QStringList &fileNames);
    Q_INVOKABLE bool addMods(const QVariantList &urls);
    Q_INVOKABLE bool openFile(const QString &fileName, const QString &category);
    Q_INVOKABLE bool openContentFolder(const QString &category);
    Q_INVOKABLE bool openScreenshot(const QString &fileName);
    Q_INVOKABLE QVariantList datapacks(const QString &world) const;
    Q_INVOKABLE bool removeDatapack(const QString &world, const QString &name);
    Q_INVOKABLE bool addDatapacks(const QString &world, const QVariantList &urls);
    Q_INVOKABLE QString readLog(const QString &fileName) const;
    QVariantList profiles() const;
    Q_INVOKABLE bool saveProfile(const QString &name);
    Q_INVOKABLE bool deleteProfile(const QString &name);
    // Returns how many mods changed state, or -1 if the profile could not be applied.
    Q_INVOKABLE int applyProfile(const QString &name);
signals:
    void changed();
    void errorOccurred(const QString &message);
private:
    bool hasMod(const QString &fileName) const;
    bool renameMod(const QString &fileName, bool enabled);
    QString profileFile() const;
    bool writeProfiles(const std::function<QString(QJsonArray &)> &change);
    InstanceModel *m_model;
    QString m_id;
    QString m_gamePath;
    InstanceContents m_contents;
    bool m_loading = false;
    quint64 m_generation = 0;
    QFileSystemWatcher m_watcher;
    QTimer m_refreshTimer;
};
