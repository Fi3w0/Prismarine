#pragma once
#include <QDateTime>
#include <QObject>
#include <QTimer>
#include <QVariantMap>

// Follows Prism's own launcher log during a launch so Prismarine can show the steps
// (signing in, game files, Java) in its own window. Prism still does the work and still
// shows its small progress dialog; this only reads what Prism writes.
class LaunchProgress : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool active READ active NOTIFY changed)
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY changed)
    // waiting, signin, files, java, game, ready, failed
    Q_PROPERTY(QString stage READ stage NOTIFY changed)
    Q_PROPERTY(QString detail READ detail NOTIFY changed)
    Q_PROPERTY(double progress READ progress NOTIFY changed)
    Q_PROPERTY(qint64 elapsedSecs READ elapsedSecs NOTIFY changed)
    Q_PROPERTY(bool abortRequested READ abortRequested NOTIFY changed)
    // True when the launch went to a Prism that was already open, which Abort leaves running.
    Q_PROPERTY(bool prismWasRunning READ prismWasRunning NOTIFY changed)
public:
    explicit LaunchProgress(const QString &dataDir, QObject *parent = nullptr, int intervalMs = 250);
    bool active() const { return !m_instanceId.isEmpty(); }
    QString instanceId() const { return m_instanceId; }
    QString stage() const { return m_stage; }
    QString detail() const { return m_detail; }
    double progress() const;
    qint64 elapsedSecs() const;
    Q_INVOKABLE void start(const QString &instanceId);
    // Later milestones come from the game's own log (GameSession): "game", "ready", or "failed".
    Q_INVOKABLE void reach(const QString &stage, const QString &detail = {});
    Q_INVOKABLE void dismiss();
    // Stops a launch: ends the Prism process Prismarine started for it (never one that was
    // already open), and asks the window to stop the game if it appears afterwards.
    Q_INVOKABLE void abort();
    bool abortRequested() const { return m_abort; }
    bool prismWasRunning() const { return m_prismWasRunning; }
    Q_INVOKABLE void poll();
    // {stage, detail} for one line of Prism's log, or empty when the line says nothing about launching.
    static QVariantMap classify(const QString &line, const QString &instanceId);
    static int rank(const QString &stage);
signals:
    void changed();
private:
    QString logPath() const;
    void advance(const QString &stage, const QString &detail);
    QString m_dataDir, m_instanceId, m_stage, m_detail, m_partial;
    QTimer m_timer;
    qint64 m_offset = 0, m_startedMs = 0, m_logIdentity = 0;
    bool m_prismWasRunning = false, m_abort = false;
    qint64 m_ownPrism = 0;
};
