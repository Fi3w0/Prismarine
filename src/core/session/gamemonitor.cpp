#include "gamemonitor.h"
#include "gamesession.h"
#include "../library/instancemodel.h"
#include "../prism/paths.h"
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>
#include <QThread>
#include "../system/system.h"

namespace {
constexpr int HistorySamples = 90;

void push(QVariantList &history, double value)
{
    history.append(value);
    if (history.size() > HistorySamples) history.removeFirst();
}
}

GameMonitor::GameMonitor(InstanceModel *instances, GameSession *primary, QObject *parent, const QString &procRoot,
                         const QString &drmRoot, int intervalMs)
    : QObject(parent), m_instances(instances), m_primary(primary), m_procRoot(procRoot), m_drmRoot(drmRoot)
{
    m_timer.setInterval(intervalMs);
    connect(&m_timer, &QTimer::timeout, this, &GameMonitor::poll);
    connect(&m_nvidiaSmi, &QProcess::finished, this, [this] {
        // name, utilization %, memory used MiB, memory total MiB
        QVariantList gpus;
        for (const QByteArray &line : m_nvidiaSmi.readAllStandardOutput().split('\n')) {
            const QList<QByteArray> parts = line.split(',');
            if (parts.size() < 4) continue;
            gpus.append(QVariantMap{{"name", QString::fromUtf8(parts.at(0)).trimmed()}, {"util", parts.at(1).trimmed().toDouble()},
                                    {"memUsedMiB", parts.at(2).trimmed().toDouble()}, {"memTotalMiB", parts.at(3).trimmed().toDouble()}});
        }
        m_nvidia = gpus;
    });
    if (intervalMs > 0) m_timer.start();
    poll();
}

GameSession *GameMonitor::followed(const QString &instanceId) const
{
    if (m_primary && m_primary->instanceId() == instanceId) return m_primary;
    return m_sessions.value(instanceId, nullptr);
}

QObject *GameMonitor::sessionFor(const QString &instanceId) const
{
    return m_sessions.value(instanceId, nullptr);
}

void GameMonitor::forget(const QString &instanceId)
{
    m_gameCpu.remove(instanceId);
    if (GameSession *session = m_sessions.take(instanceId)) session->deleteLater();
    else if (m_primary && m_primary->instanceId() == instanceId && m_primary->state() == "exited") m_primary->dismiss();
    poll();
}

void GameMonitor::scanGames()
{
    // Instance folders to recognise games by: working directory or paths in the arguments.
    struct Place { QString id, path, game; };
    QList<Place> places;
    if (m_instances) {
        for (const auto &value : m_instances->allInstances() + m_instances->copies()) {
            const QString id = value.toMap().value("instanceId").toString();
            const QString path = m_instances->instancePath(id);
            if (!path.isEmpty()) places.append({id, path, QFileInfo(Prism::gameDir(path)).canonicalFilePath()});
        }
    }
    QHash<QString, Sys::Process> running;
    for (const auto &process : Sys::processes(Sys::isJavaName, m_procRoot)) {
        if (!Sys::isJavaName(process.name) || process.zombie) continue;
        for (const Place &place : places) {
            if (!Sys::belongsToInstance(process, place.path, place.game)) continue;
            // The Mod Loading Screen helper also runs Java for the instance; the game itself
            // is the process carrying Minecraft's launch arguments.
            if (!running.contains(place.id) || process.commandLine.contains("--username") || process.commandLine.contains("--gameDir"))
                running.insert(place.id, process);
            break;
        }
    }
    for (auto it = running.cbegin(); it != running.cend(); ++it) {
        if (GameSession *existing = followed(it.key())) {
            if (existing->state() != "exited") continue;
            // Same instance started again after its previous game ended.
            if (existing == m_primary) continue;
            m_sessions.take(it.key());
            existing->deleteLater();
        }
        auto *session = new GameSession(m_instances, this, m_procRoot);
        connect(session, &GameSession::changed, this, &GameMonitor::changed);
        if (session->start(it.key())) { session->poll(); m_sessions.insert(it.key(), session); }
        else session->deleteLater();
    }

    // Per-game CPU share since the last sample, as a percentage of the whole machine.
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const double elapsedMs = m_lastSampleMs ? double(now - m_lastSampleMs) : 0;
    const int cores = qMax(1, QThread::idealThreadCount());
    QHash<qint64, quint64> cpuMs;
    QVariantList games;
    QList<GameSession *> sessions = m_sessions.values();
    if (m_primary && m_primary->active() && !m_sessions.contains(m_primary->instanceId())) sessions.prepend(m_primary);
    for (GameSession *session : sessions) {
        const QString id = session->instanceId();
        if (session != m_primary && session->state() != "exited") session->poll();
        const Sys::Process process = running.value(id);
        double cpu = 0;
        if (process.valid() && process.cpuMs >= 0) {
            cpuMs.insert(process.pid, quint64(process.cpuMs));
            if (elapsedMs > 0 && m_lastProcTicks.contains(process.pid))
                cpu = qBound(0.0, 100.0 * double(quint64(process.cpuMs) - m_lastProcTicks.value(process.pid)) / elapsedMs / cores, 100.0);
        }
        QVariantList &cpuHistory = m_gameCpu[id];
        if (process.valid()) push(cpuHistory, cpu);
        const auto info = m_instances ? m_instances->getById(id) : QVariantMap();
        games.append(QVariantMap{{"instanceId", id}, {"name", session->name()}, {"account", session->account()},
            {"pid", process.pid}, {"state", session->state()}, {"memoryMiB", session->memoryMiB()}, {"maxMemoryMiB", session->maxMemoryMiB()},
            {"cpuPercent", cpu}, {"cpuHistory", cpuHistory}, {"elapsedSecs", session->elapsedSecs()}, {"altOf", info.value("altOf")},
            {"icon", info.value("icon")}, {"loader", info.value("loader")}});
    }
    m_lastProcTicks = cpuMs;
    m_lastSampleMs = now;
    m_games = games;
}

void GameMonitor::sampleSystem()
{
    const Sys::CpuTimes times = Sys::cpuTimes(m_procRoot);
    double cpuPercent = 0;
    if (times.valid) {
        if (m_lastTotal && times.total > m_lastTotal)
            cpuPercent = 100.0 * double(times.busy - m_lastBusy) / double(times.total - m_lastTotal);
        m_lastTotal = times.total;
        m_lastBusy = times.busy;
    }
    const Sys::Memory memory = Sys::memory(m_procRoot);
    const double usedMiB = memory.totalMiB - memory.availableMiB;
    push(m_cpuHistory, cpuPercent);
    push(m_ramHistory, usedMiB);

    // A fake /proc (tests) comes with its own GPU folder; nvidia-smi is only asked on the live system.
    QVariantList gpus = Sys::gpus(m_drmRoot) + (Sys::usesNvidiaSmi() ? m_nvidia : QVariantList());
    for (auto &value : gpus) {
        auto gpu = value.toMap();
        QVariantList &history = m_gpuHistory[gpu.value("name").toString()];
        push(history, gpu.value("util").toDouble());
        gpu.insert("history", history);
        value = gpu;
    }
    m_system = {{"cpuPercent", qBound(0.0, cpuPercent, 100.0)}, {"cores", QThread::idealThreadCount()}, {"ramUsedMiB", usedMiB},
                {"ramTotalMiB", memory.totalMiB}, {"cpuHistory", m_cpuHistory}, {"ramHistory", m_ramHistory}, {"gpus", gpus}};
}

void GameMonitor::sampleGpus()
{
    if (!Sys::usesNvidiaSmi() || (!m_procRoot.isEmpty() && m_procRoot != "/proc") || m_nvidiaSmi.state() != QProcess::NotRunning) return;
    const QString smi = QStandardPaths::findExecutable("nvidia-smi");
    if (smi.isEmpty()) return;
    m_nvidiaSmi.start(smi, {"--query-gpu=name,utilization.gpu,memory.used,memory.total", "--format=csv,noheader,nounits"});
}

void GameMonitor::poll()
{
    scanGames();
    sampleGpus();
    sampleSystem();
    emit changed();
}
