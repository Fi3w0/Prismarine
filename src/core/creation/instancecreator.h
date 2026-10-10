#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantList>
#include <QJsonArray>
#include <functional>
#include "../library/instancemodel.h"

class InstanceCreator : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList versions READ versions NOTIFY changed)
    Q_PROPERTY(QVariantList loaderVersions READ loaderVersions NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit InstanceCreator(InstanceModel *model, QObject *parent = nullptr,
                             const QUrl &metadata = QUrl("https://meta.prismlauncher.org/v1"));
    QVariantList versions() const { return m_versions; }
    QVariantList loaderVersions() const { return m_loaderVersions; }
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    Q_INVOKABLE void loadVersions(bool snapshots = false);
    Q_INVOKABLE void loadLoader(const QString &loader, const QString &minecraft);
    Q_INVOKABLE QString create(const QString &name, const QString &minecraft, const QString &loader, const QString &loaderVersion);
    Q_INVOKABLE void duplicate(const QString &id, const QString &name, const QVariantMap &options);
    Q_INVOKABLE bool beginEdit(const QString &id);
    Q_INVOKABLE bool changeVersions(const QString &minecraft, const QString &loader, const QString &loaderVersion);
signals:
    void changed();
    void created(const QString &id);
    void duplicated(const QString &id);
    void modified(const QString &id);
private:
    void fetch(const QString &uid, std::function<void(const QJsonArray &)> done);
    InstanceModel *m_model;
    QUrl m_metadata;
    QNetworkAccessManager m_network;
    QVariantList m_versions, m_loaderVersions;
    QString m_error, m_loader, m_minecraft;
    bool m_loading = false;
    quint64 m_generation = 0;
    QString m_editId;
    QByteArray m_manifest;
    bool m_copying = false;
};
