#pragma once
#include <QList>
#include <QString>
#include <QStringList>
#include <QVariantList>
#include <functional>

// Everything Prismarine needs from the operating system that Qt does not cover: running
// processes, machine load, GPUs and hard links. Each system has its own backend
// (system_linux.cpp, system_windows.cpp, system_macos.cpp, system_freebsd.cpp).
//
// `procRoot` arguments: empty or "/proc" means the live system; any other folder is read
// as a Linux-style /proc tree, which is how the tests fake processes on every system.
namespace Sys {

struct Process {
    qint64 pid = 0;
    QString name;           // executable name, lower case, without ".exe"
    QString commandLine;    // all arguments joined with spaces; may be empty when not readable
    QString cwd;            // canonical working directory; empty where the system does not tell (Windows)
    qint64 residentBytes = -1;
    qint64 cpuMs = -1;      // user + system time used so far
    bool zombie = false;
    bool valid() const { return pid > 0; }
};

// Whether processes can be listed here at all.
bool processesSupported(const QString &procRoot = {});
// Running processes. Details (command line, cwd, memory, CPU time) are only read for
// processes whose name passes `wanted`, which keeps a full scan cheap.
QList<Process> processes(const std::function<bool(const QString &name)> &wanted = {}, const QString &procRoot = {});
// One process with details, or an invalid one when it has ended.
Process process(qint64 pid, const QString &procRoot = {});
// Asks a program to close like its window's close button (SIGTERM, WM_CLOSE on Windows).
bool requestClose(qint64 pid);
// Ends a process right away (SIGTERM, which Prism does not handle; TerminateProcess on Windows).
bool terminate(qint64 pid);

bool isJavaName(const QString &name);
bool isPrismName(const QString &name);
// True when the process runs in `gameDir` or names `instancePath` in its arguments, which is
// how Prism starts a game (working directory and natives/library paths).
bool belongsToInstance(const Process &process, const QString &instancePath, const QString &gameDir);

struct CpuTimes { quint64 busy = 0, total = 0; bool valid = false; };
CpuTimes cpuTimes(const QString &procRoot = {});
struct Memory { double totalMiB = 0, availableMiB = 0; };
Memory memory(const QString &procRoot = {});

// GPUs this system reports itself: [{name, util, memUsedMiB, memTotalMiB}]. NVIDIA cards on
// Linux and FreeBSD come from nvidia-smi instead (see usesNvidiaSmi). `drmRoot` replaces
// /sys/class/drm on Linux, for tests.
QVariantList gpus(const QString &drmRoot = {});
bool usesNvidiaSmi();

struct FileId { quint64 device = 0, inode = 0, links = 1; bool valid = false; };
FileId fileId(const QString &path);
bool hardLink(const QString &existing, const QString &link);
bool hardLinksSupported();
// Moves `from` over `to` in one step, replacing it (rename on Unix, MoveFileEx on Windows).
bool replaceFile(const QString &from, const QString &to);

// Linux-style /proc reader used by the Linux backend and by tests everywhere.
namespace ProcFs {
QList<Process> processes(const QString &root, const std::function<bool(const QString &)> &wanted);
Process process(const QString &root, qint64 pid);
CpuTimes cpuTimes(const QString &root);
Memory memory(const QString &root);
}
}
