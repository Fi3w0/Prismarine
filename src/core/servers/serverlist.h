#pragma once
#include <QObject>
#include <QJsonValue>
#include <QPair>
#include <QVariantList>
#include <QVariantMap>
#include "nbt.h"

class InstanceModel;

// An instance's multiplayer list (servers.dat) with live status from the server list ping.
class ServerList : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY changed)
    Q_PROPERTY(QVariantList servers READ servers NOTIFY changed)
    Q_PROPERTY(QVariantMap status READ status NOTIFY statusChanged)
public:
    explicit ServerList(InstanceModel *instances, QObject *parent = nullptr);
    QString instanceId() const { return m_instanceId; }
    QVariantList servers() const { return m_servers; }
    QVariantMap status() const { return m_status; }
    Q_INVOKABLE void load(const QString &instanceId);
    Q_INVOKABLE void refresh();
    Q_INVOKABLE bool add(const QString &name, const QString &address);
    Q_INVOKABLE bool remove(int index);
    Q_INVOKABLE bool join(int index);
    // Pings addresses that are not from a loaded instance, e.g. favourites on Home.
    Q_INVOKABLE void pingAddresses(const QStringList &addresses);
    static bool validAddress(const QString &address);
    // Flattens a status "description" (string or chat component) into plain text.
    static QString plainMotd(const QJsonValue &description);
    // Default port 25565; "[::1]:25566" and "host:25566" are understood.
    static QPair<QString, quint16> splitAddress(const QString &address, bool *explicitPort = nullptr);
signals:
    void changed();
    void statusChanged();
    void errorOccurred(const QString &message);
private:
    bool save();
    void ping(const QString &address);
    void connectAndQuery(const QString &address, const QString &host, quint16 port, quint64 generation);
    void setStatus(const QString &address, const QVariantMap &status);
    InstanceModel *m_instances;
    QString m_instanceId, m_file;
    Nbt::Tag m_root;
    QString m_rootName;
    QVariantList m_servers;
    QVariantMap m_status;
    quint64 m_generation = 0;
};
