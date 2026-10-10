// FreeBSD: processes and load through sysctl (procfs is usually not mounted), NVIDIA via
// nvidia-smi from the nvidia driver package. Other GPUs report nothing usable here.
#include "native.h"
#include <QFileInfo>
#include <sys/types.h>
#include <sys/resource.h>
#include <sys/sysctl.h>
#include <sys/proc.h>
#include <sys/user.h>
#include <unistd.h>
#include <vector>

namespace {
template <typename T> bool sysctlValue(const char *name, T *value)
{
    size_t size = sizeof(T);
    return sysctlbyname(name, value, &size, nullptr, 0) == 0;
}

QString arguments(pid_t pid)
{
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_ARGS, int(pid)};
    size_t size = 0;
    if (sysctl(mib, 4, nullptr, &size, nullptr, 0) != 0 || size == 0) return {};
    std::vector<char> buffer(size);
    if (sysctl(mib, 4, buffer.data(), &size, nullptr, 0) != 0) return {};
    QByteArray args(buffer.data(), int(size));
    args.replace('\0', ' ');
    return QString::fromUtf8(args).trimmed();
}

QString workingDirectory(pid_t pid)
{
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_CWD, int(pid)};
    struct kinfo_file file = {};
    size_t size = sizeof(file);
    if (sysctl(mib, 4, &file, &size, nullptr, 0) != 0 || size == 0) return {};
    return QFileInfo(QString::fromUtf8(file.kf_path)).canonicalFilePath();
}

Sys::Process fromKinfo(const struct kinfo_proc &info, bool details)
{
    Sys::Process p;
    p.pid = info.ki_pid;
    p.name = QString::fromUtf8(info.ki_comm).toLower();
    p.zombie = info.ki_stat == SZOMB;
    if (!details) return p;
    p.commandLine = arguments(info.ki_pid);
    p.cwd = workingDirectory(info.ki_pid);
    p.residentBytes = qint64(info.ki_rssize) * getpagesize();
    p.cpuMs = qint64(info.ki_runtime / 1000);
    return p;
}
}

bool Sys::Native::processesSupported() { return true; }

QList<Sys::Process> Sys::Native::processes(const std::function<bool(const QString &)> &wanted)
{
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PROC, 0};
    size_t size = 0;
    if (sysctl(mib, 4, nullptr, &size, nullptr, 0) != 0) return {};
    size += size / 8; // room for processes started in between
    std::vector<char> buffer(size);
    if (sysctl(mib, 4, buffer.data(), &size, nullptr, 0) != 0) return {};
    QList<Process> result;
    for (size_t offset = 0; offset + sizeof(struct kinfo_proc) <= size;) {
        const auto *info = reinterpret_cast<const struct kinfo_proc *>(buffer.data() + offset);
        if (info->ki_structsize <= 0) break;
        const QString name = QString::fromUtf8(info->ki_comm).toLower();
        result.append(fromKinfo(*info, !wanted || wanted(name)));
        offset += size_t(info->ki_structsize);
    }
    return result;
}

Sys::Process Sys::Native::process(qint64 pid)
{
    int mib[4] = {CTL_KERN, KERN_PROC, KERN_PROC_PID, int(pid)};
    struct kinfo_proc info = {};
    size_t size = sizeof(info);
    if (sysctl(mib, 4, &info, &size, nullptr, 0) != 0 || size == 0) return {};
    return fromKinfo(info, true);
}

Sys::CpuTimes Sys::Native::cpuTimes()
{
    long times[CPUSTATES] = {};
    size_t size = sizeof(times);
    if (sysctlbyname("kern.cp_time", times, &size, nullptr, 0) != 0) return {};
    CpuTimes result;
    for (long value : times) result.total += quint64(value);
    result.busy = result.total - quint64(times[CP_IDLE]);
    result.valid = true;
    return result;
}

Sys::Memory Sys::Native::memory()
{
    unsigned long physical = 0;
    u_int pageSize = 0, freePages = 0, inactivePages = 0, laundryPages = 0;
    sysctlValue("hw.physmem", &physical);
    sysctlValue("vm.stats.vm.v_page_size", &pageSize);
    sysctlValue("vm.stats.vm.v_free_count", &freePages);
    sysctlValue("vm.stats.vm.v_inactive_count", &inactivePages);
    sysctlValue("vm.stats.vm.v_laundry_count", &laundryPages);
    Memory memory;
    memory.totalMiB = double(physical) / 1048576;
    memory.availableMiB = double(quint64(freePages) + inactivePages + laundryPages) * pageSize / 1048576;
    return memory;
}

QVariantList Sys::Native::gpus(const QString &) { return {}; }
bool Sys::Native::usesNvidiaSmi() { return true; }
