#include "gamesession.h"
#include "../library/instancemodel.h"
#include "../prism/paths.h"
#include "crashanalyzer.h"
#include <QDesktopServices>
#include <QClipboard>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRegularExpression>
#include "../system/system.h"

namespace {
constexpr int MemorySamples = 90;
constexpr qint64 MaxReadPerPoll = 4 * 1024 * 1024;
constexpr qint64 MaxShareBytes = 9 * 1024 * 1024;

int memoryLimitMiB(const QString &memory)
{
    // InstanceReader formats the limit as "8 GiB" or "Prism default".
    static const QRegularExpression gib(QStringLiteral(R"(^([\d.]+) GiB$)"));
    const auto match = gib.match(memory);
    return match.hasMatch() ? int(match.captured(1).toDouble() * 1024) : 0;
}
}

GameSession::GameSession(InstanceModel *instances, QObject *parent, const QString &procRoot, const QUrl &shareEndpoint)
    : QObject(parent), m_instances(instances), m_procRoot(procRoot), m_shareEndpoint(shareEndpoint)
{
    m_filter.setSourceModel(&m_model);
    m_timer.setInterval(1000);
    connect(&m_timer, &QTimer::timeout, this, &GameSession::poll);
}

bool GameSession::tracksProcess() const
{
    return Sys::processesSupported(m_procRoot);
}

qint64 GameSession::elapsedSecs() const
{
    if (!m_startedMs) return 0;
    return ((m_endedMs ? m_endedMs : QDateTime::currentMSecsSinceEpoch()) - m_startedMs) / 1000;
}

QVariantList GameSession::steps() const
{
    QVariantList result{QVariantMap{{"title", "Launch sent to Prism"}, {"done", true}}};
    if (tracksProcess()) result.append(QVariantMap{{"title", "Game process started"}, {"done", m_pid > 0}});
    result.append(QVariantMap{{"title", m_account.isEmpty() ? QStringLiteral("Account signed in") : "Signed in as " + m_account},
                              {"done", !m_account.isEmpty()}});
    result.append(QVariantMap{{"title", "Graphics ready"}, {"done", m_graphicsReady}});
    result.append(QVariantMap{{"title", "Main menu reached"}, {"done", m_menuReached}});
    return result;
}

bool GameSession::start(const QString &instanceId)
{
    const QString path = m_instances ? m_instances->instancePath(instanceId) : QString();
    if (path.isEmpty()) return false;
    const QVariantMap info = m_instances->getById(instanceId);
    m_timer.stop();
    m_model.clear();
    m_instanceId = instanceId;
    m_name = info.value("name").toString();
    m_maxMemoryMiB = memoryLimitMiB(info.value("memory").toString());
    m_instancePath = QFileInfo(path).canonicalFilePath();
    m_gameDir = Prism::gameDir(path);
    m_account.clear();
    m_partial.clear();
    m_state = QStringLiteral("starting");
    m_startedMs = QDateTime::currentMSecsSinceEpoch();
    m_endedMs = m_offset = m_pid = 0;
    m_warnings = m_errors = m_memoryMiB = 0;
    m_graphicsReady = m_menuReached = false;
    m_memoryHistory.clear();
    m_diagnosis.clear();
    m_timer.start();
    emit changed();
    return true;
}

void GameSession::poll()
{
    if (!active() || m_state == "exited") return;
    readLog();
    if (m_state != "exited" && tracksProcess()) {
        if (m_pid <= 0) findProcess();
        if (m_pid > 0) sampleMemory();
    }
    // Without a process (another OS, or detection failed) the log alone shows the game is up.
    if (m_state == "starting" && (m_menuReached || (!tracksProcess() && m_model.rowCount() > 0)))
        m_state = QStringLiteral("running");
    emit changed();
}

void GameSession::readLog()
{
    QFile file(m_gameDir + "/logs/latest.log");
    // A log older than this launch belongs to the previous session; Minecraft replaces it on start.
    if (!file.exists() || QFileInfo(file).lastModified().toMSecsSinceEpoch() < m_startedMs - 2000) return;
    if (!file.open(QIODevice::ReadOnly)) return;
    if (file.size() < m_offset) {
        m_offset = 0;
        m_partial.clear();
        m_model.clear();
        m_warnings = m_errors = 0;
    }
    if (!file.seek(m_offset)) return;
    const QByteArray data = file.read(MaxReadPerPoll);
    m_offset += data.size();
    if (data.isEmpty()) return;
    QStringList lines = (m_partial + QString::fromUtf8(data)).split('\n');
    m_partial = lines.takeLast();
    for (QString &line : lines) {
        if (line.endsWith('\r')) line.chop(1);
        const QString level = GameLogModel::levelOf(line);
        m_warnings += level == "WARN";
        m_errors += level == "ERROR";
        if (const int user = line.indexOf("Setting user: "); user >= 0) m_account = line.mid(user + 14).trimmed();
        m_graphicsReady = m_graphicsReady || line.contains("Backend library: ");
        m_menuReached = m_menuReached || line.contains("Sound engine started");
        if (line.contains("]: Stopping!")) {
            m_model.append(lines);
            finish();
            return;
        }
    }
    m_model.append(lines);
}

void GameSession::findProcess()
{
    // Prism starts the game in its game directory and passes instance paths (natives, libraries).
    const QString gameDir = QFileInfo(m_gameDir).canonicalFilePath();
    for (const auto &process : Sys::processes(Sys::isJavaName, m_procRoot)) {
        if (!Sys::isJavaName(process.name) || process.zombie) continue;
        if (Sys::belongsToInstance(process, m_instancePath, gameDir)) {
            m_pid = process.pid;
            m_state = QStringLiteral("running");
            return;
        }
    }
}

void GameSession::sampleMemory()
{
    const Sys::Process process = Sys::process(m_pid, m_procRoot);
    if (!process.valid() || process.zombie) {
        readLog();
        finish();
        return;
    }
    if (process.residentBytes < 0) return;
    m_memoryMiB = int(process.residentBytes / 1048576);
    m_memoryHistory.append(m_memoryMiB);
    if (m_memoryHistory.size() > MemorySamples) m_memoryHistory.removeFirst();
}

void GameSession::finish()
{
    m_state = QStringLiteral("exited");
    m_endedMs = QDateTime::currentMSecsSinceEpoch();
    QString report;
    const QString text = CrashAnalyzer::collect(m_gameDir, m_startedMs, &report);
    const bool crashed = CrashAnalyzer::crashed(text);
    m_diagnosis = {{"crashed", crashed}, {"findings", crashed ? CrashAnalyzer::analyze(text) : QVariantList()}, {"report", report}};
    m_timer.stop();
    emit changed();
}

QVariantMap GameSession::diagnose(const QString &instanceId) const
{
    const QString path = m_instances ? m_instances->instancePath(instanceId) : QString();
    if (path.isEmpty()) return {};
    QString report;
    const QString text = CrashAnalyzer::collect(Prism::gameDir(path), 0, &report);
    const bool crashed = CrashAnalyzer::crashed(text);
    return {{"crashed", crashed}, {"findings", crashed ? CrashAnalyzer::analyze(text) : QVariantList()}, {"report", report}};
}

bool GameSession::openReport(const QString &path) const
{
    // Only crash reports inside an instance's crash-reports folder are opened.
    const QFileInfo file(path);
    return file.exists() && file.dir().dirName() == "crash-reports" && file.fileName().startsWith("crash-")
        && QDesktopServices::openUrl(QUrl::fromLocalFile(file.absoluteFilePath()));
}

void GameSession::stop()
{
    // Like the window's close button, so Minecraft saves and quits normally.
    if (canStop() && !Sys::requestClose(m_pid))
        emit errorOccurred(QStringLiteral("Could not stop the game. It may already have closed."));
}

void GameSession::dismiss()
{
    m_timer.stop();
    m_instanceId.clear();
    m_state = QStringLiteral("idle");
    m_model.clear();
    m_pid = 0;
    emit changed();
}

void GameSession::copyLog() const
{
    QStringList lines;
    for (int row = 0; row < m_filter.rowCount(); ++row)
        lines.append(m_filter.index(row, 0).data(GameLogModel::TextRole).toString());
    if (auto *clipboard = QGuiApplication::clipboard()) clipboard->setText(lines.join('\n'));
}

void GameSession::share()
{
    QFile file(m_gameDir + "/logs/latest.log");
    if (m_sharing || !file.open(QIODevice::ReadOnly)) {
        if (!m_sharing) emit errorOccurred(QStringLiteral("There is no log to share yet."));
        return;
    }
    if (file.size() > MaxShareBytes) file.seek(file.size() - MaxShareBytes);
    // Encode by hand: QUrlQuery leaves '+' literal, which form decoding turns into spaces.
    const QByteArray body = "content=" + QUrl::toPercentEncoding(QString::fromUtf8(file.readAll()));
    QNetworkRequest request(m_shareEndpoint);
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/x-www-form-urlencoded");
    request.setRawHeader("User-Agent", "Prismarine/0.4.0 (Qt desktop UI)");
    request.setTransferTimeout(30000);
    m_sharing = true;
    emit changed();
    auto *reply = m_network.post(request, body);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        m_sharing = false;
        const QJsonObject result = QJsonDocument::fromJson(reply->readAll()).object();
        const QString url = result.value("url").toString();
        if (reply->error() != QNetworkReply::NoError || !result.value("success").toBool() || !url.startsWith("https://"))
            emit errorOccurred(QStringLiteral("Could not upload the log to mclo.gs."));
        else {
            if (auto *clipboard = QGuiApplication::clipboard()) clipboard->setText(url);
            emit shared(url);
        }
        emit changed();
        reply->deleteLater();
    });
}
