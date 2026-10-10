#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QNetworkReply>
#include <QVariantList>
#include <QUrl>
#include "../library/instancemodel.h"

// Finds newer Modrinth versions of installed mods by file hash and replaces them after
// verifying the download. Replaced jars go to the trash (or .prismarine-removed).
class ModUpdater : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString contentType READ contentType NOTIFY changed)
    Q_PROPERTY(QString world READ world NOTIFY changed)
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY changed)
    Q_PROPERTY(QVariantList updates READ updates NOTIFY changed)
    Q_PROPERTY(QVariantMap byFile READ byFile NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit ModUpdater(InstanceModel *model, QObject *parent = nullptr,
                        const QUrl &apiRoot = QUrl("https://api.modrinth.com/v2"));
    QString contentType() const { return m_type; }
    QString world() const { return m_world; }
    QString state() const { return m_state; }
    QString instanceId() const { return m_instanceId; }
    QVariantList updates() const { return m_updates; }
    QVariantMap byFile() const;
    double progress() const { return m_progress; }
    QString error() const { return m_error; }
    Q_INVOKABLE void check(const QString &instanceId, const QString &type = "mod", const QString &world = {});
    // Updates the given installed file names; an empty list updates everything found.
    Q_INVOKABLE void update(const QStringList &fileNames = {});
    Q_INVOKABLE void cancel();
signals:
    void changed();
    void updated(const QString &instanceId, int count);
private:
    void fail(const QString &message);
    void downloadNext();
    void commit();
    InstanceModel *m_model;
    QUrl m_apiRoot;
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    QString m_state = "idle", m_instanceId, m_error, m_modsDir, m_type = "mod", m_world;
    QVariantList m_updates, m_queue;
    QList<QByteArray> m_downloaded;
    int m_index = 0;
    double m_progress = 0;
    quint64 m_generation = 0;
};
