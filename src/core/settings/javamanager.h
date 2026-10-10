#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QNetworkReply>
#include <QVariantList>
#include <QTemporaryDir>
#include <memory>
#include "../library/instancemodel.h"

namespace JavaRuntime {
QVariantMap probe(const QString &path, const QStringList &arguments = {});
QString unpack(const QString &archivePath, const QString &destination);
}
class JavaManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList runtimes READ runtimes NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(QString message READ message NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
public:
    explicit JavaManager(InstanceModel *model, QObject *parent = nullptr,
                         const QUrl &api = QUrl("https://api.adoptium.net/v3"));
    QVariantList runtimes() const { return m_runtimes; }
    bool busy() const { return m_busy; }
    QString message() const { return m_message; }
    double progress() const { return m_progress; }
    Q_INVOKABLE void discover();
    Q_INVOKABLE void test(const QString &path, const QString &arguments, int minMemory, int maxMemory);
    Q_INVOKABLE void download(int major);
signals:
    void changed();
private:
    void finish(const QString &message);
    QString installRoot() const;
    InstanceModel *m_model;
    QUrl m_api;
    QNetworkAccessManager m_network;
    QVariantList m_runtimes;
    bool m_busy = false;
    QString m_message;
    double m_progress = 0;
};
