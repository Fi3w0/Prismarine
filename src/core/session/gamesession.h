#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QTimer>
#include <QUrl>
#include <QVariantList>
#include "gamelog.h"

class InstanceModel;

// Follows a game that Prism launched: tails latest.log, finds the Java process through /proc
// (Linux), samples its memory, and marks launch milestones. Prism still owns the launch itself.
class GameSession : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(QString state READ state NOTIFY changed)
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QString account READ account NOTIFY changed)
    Q_PROPERTY(qint64 elapsedSecs READ elapsedSecs NOTIFY changed)
    Q_PROPERTY(QVariantList steps READ steps NOTIFY changed)
    Q_PROPERTY(bool graphicsReady READ graphicsReady NOTIFY changed)
    Q_PROPERTY(bool menuReached READ menuReached NOTIFY changed)
    Q_PROPERTY(bool processFound READ processFound NOTIFY changed)
    Q_PROPERTY(int warnings READ warnings NOTIFY changed)
    Q_PROPERTY(int errors READ errors NOTIFY changed)
    Q_PROPERTY(int memoryMiB READ memoryMiB NOTIFY changed)
    Q_PROPERTY(int maxMemoryMiB READ maxMemoryMiB NOTIFY changed)
    Q_PROPERTY(QVariantList memoryHistory READ memoryHistory NOTIFY changed)
    Q_PROPERTY(bool canStop READ canStop NOTIFY changed)
    Q_PROPERTY(bool tracksProcess READ tracksProcess CONSTANT)
    Q_PROPERTY(bool sharing READ sharing NOTIFY changed)
    Q_PROPERTY(GameLogFilter *log READ log CONSTANT)
    // After the game exits: {crashed, findings, report} from the crash helper.
    Q_PROPERTY(QVariantMap diagnosis READ diagnosis NOTIFY changed)
public:
    explicit GameSession(InstanceModel *instances, QObject *parent = nullptr, const QString &procRoot = {},
                         const QUrl &shareEndpoint = QUrl("https://api.mclo.gs/1/log"));
    bool active() const { return !m_instanceId.isEmpty(); }
    QString state() const { return m_state; }
    QString instanceId() const { return m_instanceId; }
    QString name() const { return m_name; }
    QString account() const { return m_account; }
    qint64 elapsedSecs() const;
    QVariantList steps() const;
    bool graphicsReady() const { return m_graphicsReady; }
    bool menuReached() const { return m_menuReached; }
    bool processFound() const { return m_pid > 0; }
    int warnings() const { return m_warnings; }
    int errors() const { return m_errors; }
    int memoryMiB() const { return m_memoryMiB; }
    int maxMemoryMiB() const { return m_maxMemoryMiB; }
    QVariantList memoryHistory() const { return m_memoryHistory; }
    bool canStop() const { return m_pid > 0 && m_state != "exited"; }
    bool tracksProcess() const;
    bool sharing() const { return m_sharing; }
    GameLogFilter *log() { return &m_filter; }
    QVariantMap diagnosis() const { return m_diagnosis; }
    // Explains the newest log and crash report of any instance, for the Logs tab.
    Q_INVOKABLE QVariantMap diagnose(const QString &instanceId) const;
    Q_INVOKABLE bool openReport(const QString &path) const;

    // Begins following an instance after Prism accepted its launch request.
    Q_INVOKABLE bool start(const QString &instanceId);
    Q_INVOKABLE void stop();
    Q_INVOKABLE void dismiss();
    Q_INVOKABLE void copyLog() const;
    // Uploads latest.log to mclo.gs; the page asks the user first because the result is public.
    Q_INVOKABLE void share();
    Q_INVOKABLE void poll();
signals:
    void changed();
    void shared(const QString &url);
    void errorOccurred(const QString &message);
private:
    void readLog();
    void findProcess();
    void sampleMemory();
    void finish();
    InstanceModel *m_instances;
    QString m_procRoot;
    QUrl m_shareEndpoint;
    QNetworkAccessManager m_network;
    QTimer m_timer;
    GameLogModel m_model;
    GameLogFilter m_filter;
    QString m_instanceId, m_name, m_account, m_state = "idle", m_gameDir, m_instancePath, m_partial;
    qint64 m_startedMs = 0, m_endedMs = 0, m_offset = 0;
    qint64 m_pid = 0;
    int m_warnings = 0, m_errors = 0, m_memoryMiB = 0, m_maxMemoryMiB = 0;
    bool m_graphicsReady = false, m_menuReached = false, m_sharing = false;
    QVariantList m_memoryHistory;
    QVariantMap m_diagnosis;
};
