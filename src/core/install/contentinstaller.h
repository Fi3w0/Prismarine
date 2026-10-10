#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QNetworkReply>
#include <QJsonObject>
#include <QJsonDocument>
#include <QPointer>
#include <QVariantList>
#include <QTemporaryDir>
#include <QSet>
#include <functional>
#include <memory>
#include "../library/instancemodel.h"

class ContentInstaller : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QVariantList plan READ plan NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY changed)
    Q_PROPERTY(QString world READ world NOTIFY changed)
public:
    explicit ContentInstaller(InstanceModel *model, QObject *parent = nullptr,
                              const QUrl &apiRoot = QUrl("https://api.modrinth.com/v2"),
                              const QUrl &curseApi = QUrl("https://api.curseforge.com/v1"));
    void setCurseForgeKey(const QByteArray &key) { m_curseKey = key; }
    QString state() const { return m_state; }
    QString error() const { return m_error; }
    QVariantList plan() const { return m_plan; }
    double progress() const { return m_progress; }
    QString instanceId() const { return m_id; }
    QString world() const { return m_world; }
    Q_INVOKABLE void prepare(const QString &instanceId, const QVariantMap &version, const QString &type, const QString &world = {});
    Q_INVOKABLE void prepareMany(const QString &instanceId, const QVariantList &versions, const QString &type, const QString &world = {});
    Q_INVOKABLE void install();
    Q_INVOKABLE void cancel();
signals:
    void changed();
    void installed(const QString &instanceId, int count);
private:
    void fail(const QString &error);
    void resolveNext();
    void resolveCurseForge(const QJsonObject &dependency);
    void indexCurseForge(const QJsonArray &selected);
    void indexInstalled(const QJsonArray &selected);
    void appendSelection(const QJsonArray &selected);
    bool appendVersion(const QJsonObject &version);
    void getJson(const QUrl &url, std::function<void(const QJsonDocument &)> done);
    void downloadNext();
    void commit();
    InstanceModel *m_model;
    QUrl m_apiRoot, m_curseApi;
    QByteArray m_curseKey;
    QString m_provider;
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    QString m_state = "idle", m_error, m_id, m_target, m_type, m_world, m_gameVersion, m_loader;
    QVariantList m_plan;
    QList<QJsonObject> m_pending, m_incompatible;
    QSet<QString> m_seen, m_projects, m_requested;
    QMap<QString, QString> m_installedProjects;
    std::unique_ptr<QTemporaryDir> m_staging;
    int m_downloadIndex = 0;
    double m_progress = 0;
    quint64 m_generation = 0;
};
