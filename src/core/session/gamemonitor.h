#pragma once
#include <QHash>
#include <QObject>
#include <QPointer>
#include <QProcess>
#include <QTimer>
#include <QVariantList>
#include <QVariantMap>

class GameSession;
class InstanceModel;

// Watches every running game (any instance, including multi-account copies) and the
// machine as a whole. Each game gets its own GameSession for its log and memory; the
// session Prismarine launched itself (`primary`) is reused instead of duplicated.
class GameMonitor : public QObject {
    Q_OBJECT
    // [{instanceId, name, account, pid, state, memoryMiB, cpuPercent, cpuHistory, elapsedSecs, altOf}]
    Q_PROPERTY(QVariantList games READ games NOTIFY changed)
    // {cpuPercent, cores, ramUsedMiB, ramTotalMiB, cpuHistory, ramHistory, gpus: [{name, util, memUsedMiB, memTotalMiB, history}]}
    Q_PROPERTY(QVariantMap system READ system NOTIFY changed)
public:
    explicit GameMonitor(InstanceModel *instances, GameSession *primary, QObject *parent = nullptr,
                         const QString &procRoot = {}, const QString &drmRoot = {}, int intervalMs = 2000);
    QVariantList games() const { return m_games; }
    QVariantMap system() const { return m_system; }
    // The session the monitor follows for this instance's game, or null when it is not
    // followed or is the primary one: QML would take ownership of the parentless primary
    // session and delete it, so callers fall back to the primary session themselves.
    Q_INVOKABLE QObject *sessionFor(const QString &instanceId) const;
    // Removes a finished game from the list.
    Q_INVOKABLE void forget(const QString &instanceId);
    Q_INVOKABLE void poll();
signals:
    void changed();
private:
    void scanGames();
    void sampleSystem();
    void sampleGpus();
    GameSession *followed(const QString &instanceId) const;
    InstanceModel *m_instances;
    QPointer<GameSession> m_primary;
    QString m_procRoot, m_drmRoot;
    QTimer m_timer;
    QHash<QString, GameSession *> m_sessions;
    QHash<qint64, quint64> m_lastProcTicks; // CPU milliseconds per game process at the last sample
    quint64 m_lastTotal = 0, m_lastBusy = 0; // machine CPU time: total and busy at the last sample
    QVariantList m_games, m_cpuHistory, m_ramHistory;
    QVariantMap m_system;
    QVariantList m_nvidia;
    QHash<QString, QVariantList> m_gpuHistory, m_gameCpu;
    QProcess m_nvidiaSmi;
    qint64 m_lastSampleMs = 0;
};
