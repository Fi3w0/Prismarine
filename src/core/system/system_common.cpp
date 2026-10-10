#include "system.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>

namespace {
QByteArray readFile(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}

QString normalizedName(QString name)
{
    name = name.trimmed().toLower();
    if (name.endsWith(".exe")) name.chop(4);
    return name;
}
}

bool Sys::isJavaName(const QString &name)
{
    const QString n = normalizedName(name);
    return n == "java" || n == "javaw";
}

bool Sys::isPrismName(const QString &name)
{
    // Linux shortens process names to 15 characters, which still fits "prismlauncher".
    const QString n = normalizedName(name);
    return n == "prismlauncher" || n == "prismlauncher-q" || n == "prism launcher";
}

bool Sys::belongsToInstance(const Process &process, const QString &instancePath, const QString &gameDir)
{
    if (!gameDir.isEmpty() && !process.cwd.isEmpty() && process.cwd == gameDir) return true;
    if (instancePath.isEmpty() || process.commandLine.isEmpty()) return false;
    // Windows command lines may use either separator, and paths there ignore case.
    QString command = process.commandLine;
    QString path = instancePath + "/";
    command.replace('\\', '/');
    path.replace('\\', '/');
#ifdef Q_OS_WIN
    return command.contains(path, Qt::CaseInsensitive);
#else
    return command.contains(path);
#endif
}

QList<Sys::Process> Sys::ProcFs::processes(const QString &root, const std::function<bool(const QString &)> &wanted)
{
    QList<Process> result;
    for (const QString &entry : QDir(root).entryList(QDir::Dirs | QDir::NoDotAndDotDot)) {
        bool numeric = false;
        const qint64 pid = entry.toLongLong(&numeric);
        if (!numeric || !QFileInfo::exists(root + "/" + entry + "/status")) continue;
        QString name = QString::fromUtf8(readFile(root + "/" + entry + "/comm")).trimmed();
        if (name.isEmpty()) {
            // Without comm (fake trees in tests), the program in the command line names it.
            const QByteArray argv0 = readFile(root + "/" + entry + "/cmdline").split('\0').value(0);
            name = QFileInfo(QString::fromUtf8(argv0)).fileName();
        }
        if (wanted && !wanted(normalizedName(name))) {
            Process bare;
            bare.pid = pid;
            bare.name = normalizedName(name);
            result.append(bare);
            continue;
        }
        Process full = process(root, pid);
        if (full.valid()) result.append(full);
    }
    return result;
}

Sys::Process Sys::ProcFs::process(const QString &root, qint64 pid)
{
    const QString dir = root + "/" + QString::number(pid);
    const QByteArray status = readFile(dir + "/status");
    if (status.isEmpty()) return {};
    Process p;
    p.pid = pid;
    const QByteArray cmdline = readFile(dir + "/cmdline");
    p.name = normalizedName(QString::fromUtf8(readFile(dir + "/comm")));
    if (p.name.isEmpty()) p.name = normalizedName(QFileInfo(QString::fromUtf8(cmdline.split('\0').value(0))).fileName());
    QByteArray joined = cmdline;
    joined.replace('\0', ' ');
    p.commandLine = QString::fromUtf8(joined).trimmed();
    p.cwd = QFileInfo(dir + "/cwd").canonicalFilePath();
    static const QRegularExpression rss(QStringLiteral(R"(VmRSS:\s+(\d+) kB)"));
    if (const auto match = rss.match(QString::fromUtf8(status)); match.hasMatch()) p.residentBytes = match.captured(1).toLongLong() * 1024;
    static const QRegularExpression state(QStringLiteral(R"(State:\s+Z)"));
    p.zombie = state.match(QString::fromUtf8(status)).hasMatch();
    // utime + stime: fields 14 and 15 of stat, counted after the parenthesised name.
    const QByteArray stat = readFile(dir + "/stat");
    if (const int close = stat.lastIndexOf(')'); close > 0) {
        const QList<QByteArray> fields = stat.mid(close + 2).split(' ');
        if (fields.value(0) == "Z") p.zombie = true;
        if (fields.size() > 12) {
            // Linux reports these in USER_HZ, which is 100 on every architecture it supports.
            p.cpuMs = (fields.at(11).toLongLong() + fields.at(12).toLongLong()) * 10;
        }
    }
    return p;
}

Sys::CpuTimes Sys::ProcFs::cpuTimes(const QString &root)
{
    const QList<QByteArray> cpu = readFile(root + "/stat").split('\n').value(0).simplified().split(' ');
    if (cpu.size() < 6 || cpu.at(0) != "cpu") return {};
    CpuTimes times;
    for (int i = 1; i < cpu.size(); ++i) times.total += cpu.at(i).toULongLong();
    const quint64 idle = cpu.at(4).toULongLong() + cpu.at(5).toULongLong();
    times.busy = times.total - idle;
    times.valid = true;
    return times;
}

Sys::Memory Sys::ProcFs::memory(const QString &root)
{
    Memory memory;
    for (const QByteArray &line : readFile(root + "/meminfo").split('\n')) {
        const QList<QByteArray> parts = line.simplified().split(' ');
        if (parts.size() < 2) continue;
        if (parts.at(0) == "MemTotal:") memory.totalMiB = parts.at(1).toDouble() / 1024;
        if (parts.at(0) == "MemAvailable:") memory.availableMiB = parts.at(1).toDouble() / 1024;
    }
    return memory;
}

#include "native.h"

namespace {
bool fake(const QString &procRoot)
{
    return !procRoot.isEmpty() && procRoot != "/proc";
}
}

bool Sys::processesSupported(const QString &procRoot)
{
    return fake(procRoot) ? QFileInfo(procRoot).isDir() : Native::processesSupported();
}

QList<Sys::Process> Sys::processes(const std::function<bool(const QString &)> &wanted, const QString &procRoot)
{
    return fake(procRoot) ? ProcFs::processes(procRoot, wanted) : Native::processes(wanted);
}

Sys::Process Sys::process(qint64 pid, const QString &procRoot)
{
    if (pid <= 0) return {};
    return fake(procRoot) ? ProcFs::process(procRoot, pid) : Native::process(pid);
}

bool Sys::requestClose(qint64 pid) { return pid > 0 && Native::requestClose(pid); }
bool Sys::terminate(qint64 pid) { return pid > 0 && Native::terminate(pid); }
Sys::CpuTimes Sys::cpuTimes(const QString &procRoot) { return fake(procRoot) ? ProcFs::cpuTimes(procRoot) : Native::cpuTimes(); }
Sys::Memory Sys::memory(const QString &procRoot) { return fake(procRoot) ? ProcFs::memory(procRoot) : Native::memory(); }
QVariantList Sys::gpus(const QString &drmRoot) { return Native::gpus(drmRoot); }
bool Sys::usesNvidiaSmi() { return Native::usesNvidiaSmi(); }
Sys::FileId Sys::fileId(const QString &path) { return Native::fileId(path); }
bool Sys::hardLink(const QString &existing, const QString &link) { return Native::hardLink(existing, link); }
bool Sys::replaceFile(const QString &from, const QString &to) { return Native::replaceFile(from, to); }

bool Sys::hardLinksSupported()
{
#if defined(Q_OS_UNIX) || defined(Q_OS_WIN)
    return true;
#else
    return false;
#endif
}
