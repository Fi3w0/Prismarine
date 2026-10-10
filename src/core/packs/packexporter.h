#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QNetworkReply>
#include <QUrl>
#include <QVariantMap>
#include "../library/instancemodel.h"

// One file chosen for a pack: its path inside the game folder and, once known, its Modrinth source.
struct ExportFile {
    QString relative, absolute, sha1, sha512, url;
    qint64 size = 0;
};

// Builds a shareable modpack from an instance. ".mrpack" lists Modrinth-hosted files as downloads and
// stores everything else as overrides; ".zip" is a complete Prism/MultiMC instance export.
class PackExporter : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QString output READ output NOTIFY changed)
    Q_PROPERTY(QVariantMap summary READ summary NOTIFY changed)
public:
    explicit PackExporter(InstanceModel *model, QObject *parent = nullptr,
                          const QUrl &apiRoot = QUrl("https://api.modrinth.com/v2"));
    QString state() const { return m_state; }
    QString name() const { return m_name; }
    double progress() const { return m_progress; }
    QString error() const { return m_error; }
    QString output() const { return m_output; }
    QVariantMap summary() const { return m_summary; }
    // options: configs, resources, options, servers, worlds, disabled (bools); version and description (text).
    Q_INVOKABLE void exportPack(const QString &instanceId, const QUrl &destination, const QString &format, const QVariantMap &options);
    Q_INVOKABLE void cancel();
    static QList<ExportFile> chooseFiles(const QString &gameDir, const QVariantMap &options);
signals:
    void changed();
    void exported(const QString &path);
private:
    void fail(const QString &message);
    void lookUp(QList<ExportFile> files);
    void write(const QList<ExportFile> &files);
    InstanceModel *m_model;
    QUrl m_apiRoot;
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    QString m_state = "idle", m_name, m_error, m_output, m_format, m_instanceId, m_gameDir, m_instancePath;
    QVariantMap m_options, m_summary;
    double m_progress = 0;
    quint64 m_generation = 0;
};
