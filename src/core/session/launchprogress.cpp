#include "launchprogress.h"
#include <QFile>
#include <QFileInfo>
#include <QDir>
#include <QRegularExpression>
#include "../prism/paths.h"
#include "../prism/launcherbridge.h"
#include "../system/system.h"

namespace {
const QStringList order{"waiting", "signin", "files", "java", "game", "ready"};

// Prism rotates PrismLauncher-0.log when it starts; a new inode means a new file.
qint64 identity(const QString &path)
{
    // On Windows the file index plays the part of the inode.
    if (const Sys::FileId id = Sys::fileId(path); id.valid) return qint64(id.inode);
    return QFileInfo(path).birthTime().toMSecsSinceEpoch();
}
}

LaunchProgress::LaunchProgress(const QString &dataDir, QObject *parent, int intervalMs) : QObject(parent), m_dataDir(dataDir)
{
    m_timer.setInterval(intervalMs);
    connect(&m_timer, &QTimer::timeout, this, &LaunchProgress::poll);
}

QString LaunchProgress::logPath() const
{
    // Prism 9+ writes logs/PrismLauncher-0.log; older versions wrote it in the data folder.
    const QString current = m_dataDir + "/logs/PrismLauncher-0.log";
    return QFileInfo::exists(current) || QFileInfo::exists(m_dataDir + "/logs") ? current : m_dataDir + "/PrismLauncher-0.log";
}

int LaunchProgress::rank(const QString &stage)
{
    return order.indexOf(stage);
}

double LaunchProgress::progress() const
{
    static const QHash<QString, double> values{{"waiting", 0.06}, {"signin", 0.22}, {"files", 0.45}, {"java", 0.64}, {"game", 0.84}, {"ready", 1.0}};
    return values.value(m_stage, 0.0);
}

qint64 LaunchProgress::elapsedSecs() const
{
    return m_startedMs ? (QDateTime::currentMSecsSinceEpoch() - m_startedMs) / 1000 : 0;
}

QVariantMap LaunchProgress::classify(const QString &line, const QString &instanceId)
{
    static const QRegularExpression launching(R"re(<> Instance "(.+)" launching)re");
    static const QRegularExpression auth(R"re(AuthFlow: "(.+)")re");
    static const QRegularExpression failure(R"re((?i)(launch(ing)? (was )?(aborted|failed|cancelled)|could not launch|unable to launch|failed to (log ?in|authenticate|refresh)))re");
    if (const auto match = launching.match(line); match.hasMatch())
        return match.captured(1) == instanceId ? QVariantMap{{"stage", "signin"}, {"detail", "Prism accepted the launch"}} : QVariantMap();
    if (const auto match = auth.match(line); match.hasMatch()) {
        QString message = match.captured(1).trimmed();
        if (message.endsWith('.')) message.chop(1);
        // Never echo anything token-like from the log.
        if (message.contains("token", Qt::CaseInsensitive)) message = "Fetching Minecraft access";
        const bool failed = message.contains("fail", Qt::CaseInsensitive) || message.contains("error", Qt::CaseInsensitive);
        return {{"stage", failed ? "failed" : "signin"}, {"detail", message}};
    }
    if (failure.match(line).hasMatch()) {
        QString text = line.section(": ", 1).trimmed();
        text.remove(QRegularExpression(R"re(\s*\(unknown:0\)$)re"));
        return {{"stage", "failed"}, {"detail", text.left(200)}};
    }
    if (line.contains(": downloading libraries") || line.contains("reconstructAssets") || line.contains("Checking game files")
        || (line.contains("Downloading") && !line.contains("Translations")))
        return {{"stage", "files"}, {"detail", line.contains("reconstructAssets") ? "Checking game assets" : "Downloading libraries"}};
    if (line.contains(" -Xmx") || line.contains("-Djava.library.path"))
        return {{"stage", "java"}, {"detail", "Starting Java"}};
    return {};
}

void LaunchProgress::start(const QString &instanceId)
{
    m_instanceId = instanceId;
    m_stage = "waiting";
    m_detail = "Asking Prism Launcher to start the game";
    m_partial.clear();
    m_startedMs = QDateTime::currentMSecsSinceEpoch();
    // Launches go through Prism::startLauncher just before this, which knows whether it
    // started a new Prism; asking now would count that new Prism as already running.
    m_ownPrism = Prism::lastStartedLauncher();
    m_prismWasRunning = m_ownPrism == 0;
    m_abort = false;
    const QString path = logPath();
    m_offset = QFileInfo(path).size();
    m_logIdentity = identity(path);
    m_timer.start();
    emit changed();
}

void LaunchProgress::advance(const QString &stage, const QString &detail)
{
    if (stage == "failed") {
        m_stage = stage;
        m_detail = detail;
        m_timer.stop();
        return;
    }
    // Steps only move forward; a later account refresh must not rewind the display.
    if (rank(stage) < rank(m_stage)) return;
    m_stage = stage;
    if (!detail.isEmpty()) m_detail = detail;
}

void LaunchProgress::reach(const QString &stage, const QString &detail)
{
    if (!active() || m_stage == "failed") return;
    advance(stage, detail);
    if (m_stage == "ready") m_timer.stop();
    emit changed();
}

void LaunchProgress::abort()
{
    if (!active() || m_stage == "ready") return;
    m_abort = true;
    // A Prism started for this launch exists only for it; one the user had open is left alone.
    // Checked by name first, in case the process id was reused after Prism ended.
    if (const Sys::Process prism = Sys::process(m_ownPrism); prism.valid() && Sys::isPrismName(prism.name) && !prism.zombie) {
        if (Sys::terminate(prism.pid)) qInfo() << "Prismarine: stopped Prism" << prism.pid << "for an aborted launch";
    }
    m_stage = "failed";
    m_detail = m_prismWasRunning ? "Launch aborted. Prism was already open, so the game is stopped as soon as it starts."
                                 : "Launch aborted.";
    m_timer.stop();
    emit changed();
}

void LaunchProgress::dismiss()
{
    m_timer.stop();
    m_instanceId.clear();
    m_stage.clear();
    m_detail.clear();
    emit changed();
}

void LaunchProgress::poll()
{
    if (!active()) return;
    const QString path = logPath();
    if (const qint64 current = identity(path); current != m_logIdentity) {
        // Prism started fresh and rotated its log: read the new file from the start.
        m_logIdentity = current;
        m_offset = 0;
        m_partial.clear();
    }
    QFile file(path);
    if (file.open(QIODevice::ReadOnly)) {
        if (file.size() < m_offset) m_offset = 0;
        if (file.seek(m_offset)) {
            const QByteArray data = file.read(512 * 1024);
            m_offset += data.size();
            QStringList lines = (m_partial + QString::fromUtf8(data)).split('\n');
            m_partial = lines.takeLast();
            for (const auto &line : lines) {
                const auto step = classify(line, m_instanceId);
                if (!step.isEmpty()) advance(step.value("stage").toString(), step.value("detail").toString());
                if (m_stage == "failed") break;
            }
        }
    }
    if (m_stage == "waiting" && elapsedSecs() >= 20)
        m_detail = "Still waiting for Prism Launcher. Check whether it opened a window.";
    emit changed();
}
