#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QNetworkReply>
#include <QTemporaryDir>
#include <memory>
#include "../library/instancemodel.h"

struct PackPlan {
    QString error, name, instanceRoot;
    QVariantList files;
    bool modrinth = false;
    // CurseForge, ATLauncher, Technic or FTB archives, which Prism's own importer handles.
    bool foreign = false;
};
PackPlan extractPack(const QString &archivePath, const QString &staging);
bool applyPackOverrides(const QString &staging, QString *error);

class PackImporter : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
public:
    explicit PackImporter(InstanceModel *model, QObject *parent = nullptr, const QUrl &api = QUrl("https://api.modrinth.com/v2")) : QObject(parent), m_model(model), m_api(api) {}
    QString state() const { return m_state; }
    QString error() const { return m_error; }
    double progress() const { return m_progress; }
    Q_INVOKABLE void importFile(const QUrl &source);
    Q_INVOKABLE void importVersion(const QVariantMap &version);
    Q_INVOKABLE void cancel();
signals:
    void changed();
    void imported(const QString &id);
    void handedOff(const QString &format);
private:
    void fail(const QString &error);
    void downloadNext();
    void finish();
    InstanceModel *m_model;
    QUrl m_api;
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    std::shared_ptr<QTemporaryDir> m_staging;
    std::shared_ptr<QTemporaryDir> m_archive;
    PackPlan m_plan;
    QString m_state = "idle", m_error;
    QUrl m_source;
    double m_progress = 0;
    int m_index = 0;
    quint64 m_generation = 0;
};
