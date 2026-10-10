// macOS: processes through libproc and sysctl, load through Mach host statistics, GPU load
// from IOKit's accelerator statistics (Apple silicon and Intel/AMD Macs alike).
#include "native.h"
#include <QFileInfo>
#include <CoreFoundation/CoreFoundation.h>
#include <IOKit/IOKitLib.h>
#include <libproc.h>
#include <mach/mach.h>
#include <mach/mach_time.h>
#include <sys/proc.h>
#include <sys/proc_info.h>
#include <sys/sysctl.h>
#include <cstring>
#include <vector>

namespace {
// Task times come in Mach absolute time units, which are not nanoseconds on Apple silicon.
qint64 machToMs(uint64_t value)
{
    static mach_timebase_info_data_t base = [] { mach_timebase_info_data_t info{}; mach_timebase_info(&info); return info; }();
    return qint64(double(value) * base.numer / base.denom / 1e6);
}

QString arguments(pid_t pid)
{
    int argmax = 0;
    size_t size = sizeof(argmax);
    int mibMax[2] = {CTL_KERN, KERN_ARGMAX};
    if (sysctl(mibMax, 2, &argmax, &size, nullptr, 0) != 0 || argmax <= 0) return {};
    std::vector<char> buffer(static_cast<size_t>(argmax));
    int mib[3] = {CTL_KERN, KERN_PROCARGS2, int(pid)};
    size = buffer.size();
    if (sysctl(mib, 3, buffer.data(), &size, nullptr, 0) != 0 || size <= sizeof(int)) return {};
    // Layout: argc, the executable path, padding NULs, then argc NUL-terminated arguments.
    int argc = 0;
    memcpy(&argc, buffer.data(), sizeof(argc));
    size_t pos = sizeof(argc);
    while (pos < size && buffer[pos] != '\0') ++pos;
    while (pos < size && buffer[pos] == '\0') ++pos;
    QStringList args;
    while (pos < size && args.size() < argc) {
        const char *start = buffer.data() + pos;
        const size_t length = strnlen(start, size - pos);
        args.append(QString::fromUtf8(start, int(length)));
        pos += length + 1;
    }
    return args.join(' ');
}

Sys::Process describe(pid_t pid, bool details)
{
    Sys::Process p;
    char name[2 * MAXCOMLEN + 1] = {};
    if (proc_name(pid, name, sizeof(name)) <= 0) {
        // Other users' processes refuse most queries; the pid is still worth listing.
        struct proc_bsdshortinfo info = {};
        if (proc_pidinfo(pid, PROC_PIDT_SHORTBSDINFO, 0, &info, sizeof(info)) <= 0) return p;
        strncpy(name, info.pbsi_comm, sizeof(name) - 1);
    }
    p.pid = pid;
    p.name = QString::fromUtf8(name).toLower();
    if (!details) return p;
    p.commandLine = arguments(pid);
    struct proc_taskinfo task = {};
    if (proc_pidinfo(pid, PROC_PIDTASKINFO, 0, &task, sizeof(task)) == int(sizeof(task))) {
        p.residentBytes = qint64(task.pti_resident_size);
        p.cpuMs = machToMs(task.pti_total_user + task.pti_total_system);
    }
    struct proc_vnodepathinfo paths = {};
    if (proc_pidinfo(pid, PROC_PIDVNODEPATHINFO, 0, &paths, sizeof(paths)) == int(sizeof(paths)))
        p.cwd = QFileInfo(QString::fromUtf8(paths.pvi_cdir.vip_path)).canonicalFilePath();
    struct proc_bsdinfo bsd = {};
    if (proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &bsd, sizeof(bsd)) == int(sizeof(bsd))) p.zombie = bsd.pbi_status == SZOMB;
    return p;
}

double numberIn(CFDictionaryRef dictionary, const char *key)
{
    CFStringRef name = CFStringCreateWithCString(kCFAllocatorDefault, key, kCFStringEncodingUTF8);
    const void *value = CFDictionaryGetValue(dictionary, name);
    CFRelease(name);
    double result = -1;
    if (value && CFGetTypeID(value) == CFNumberGetTypeID()) CFNumberGetValue(CFNumberRef(value), kCFNumberDoubleType, &result);
    return result;
}

QString modelOf(io_registry_entry_t accelerator)
{
    // The PCI device above an accelerator carries its marketing name; Apple silicon does not.
    io_registry_entry_t parent = 0;
    QString model;
    if (IORegistryEntryGetParentEntry(accelerator, kIOServicePlane, &parent) == KERN_SUCCESS) {
        if (CFTypeRef value = IORegistryEntryCreateCFProperty(parent, CFSTR("model"), kCFAllocatorDefault, 0)) {
            if (CFGetTypeID(value) == CFDataGetTypeID())
                model = QString::fromUtf8(reinterpret_cast<const char *>(CFDataGetBytePtr(CFDataRef(value))), int(CFDataGetLength(CFDataRef(value)))).remove(QChar(0));
            CFRelease(value);
        }
        IOObjectRelease(parent);
    }
    return model.isEmpty() ? QStringLiteral("Apple GPU") : model.trimmed();
}
}

bool Sys::Native::processesSupported() { return true; }

QList<Sys::Process> Sys::Native::processes(const std::function<bool(const QString &)> &wanted)
{
    const int count = proc_listallpids(nullptr, 0);
    if (count <= 0) return {};
    std::vector<pid_t> pids(size_t(count) + 64);
    const int found = proc_listallpids(pids.data(), int(pids.size() * sizeof(pid_t)));
    QList<Process> result;
    for (int i = 0; i < found; ++i) {
        if (pids[size_t(i)] <= 0) continue;
        Process bare = describe(pids[size_t(i)], false);
        if (!bare.valid()) continue;
        result.append(!wanted || wanted(bare.name) ? describe(pids[size_t(i)], true) : bare);
    }
    return result;
}

Sys::Process Sys::Native::process(qint64 pid) { return describe(pid_t(pid), true); }

Sys::CpuTimes Sys::Native::cpuTimes()
{
    host_cpu_load_info_data_t load = {};
    mach_msg_type_number_t count = HOST_CPU_LOAD_INFO_COUNT;
    if (host_statistics(mach_host_self(), HOST_CPU_LOAD_INFO, host_info_t(&load), &count) != KERN_SUCCESS) return {};
    CpuTimes times;
    for (int state = 0; state < CPU_STATE_MAX; ++state) times.total += load.cpu_ticks[state];
    times.busy = times.total - load.cpu_ticks[CPU_STATE_IDLE];
    times.valid = true;
    return times;
}

Sys::Memory Sys::Native::memory()
{
    Memory memory;
    uint64_t physical = 0;
    size_t size = sizeof(physical);
    if (sysctlbyname("hw.memsize", &physical, &size, nullptr, 0) == 0) memory.totalMiB = double(physical) / 1048576;
    vm_statistics64_data_t vm = {};
    mach_msg_type_number_t count = HOST_VM_INFO64_COUNT;
    if (host_statistics64(mach_host_self(), HOST_VM_INFO64, host_info64_t(&vm), &count) == KERN_SUCCESS) {
        // Close to Activity Monitor: free, cached files and memory apps marked as purgeable.
        const uint64_t pages = uint64_t(vm.free_count) + vm.inactive_count + vm.speculative_count + vm.purgeable_count;
        memory.availableMiB = double(pages) * double(vm_kernel_page_size) / 1048576;
    }
    return memory;
}

QVariantList Sys::Native::gpus(const QString &)
{
    QVariantList result;
    io_iterator_t iterator = 0;
    // 0 is the default main port on every macOS version.
    if (IOServiceGetMatchingServices(0, IOServiceMatching("IOAccelerator"), &iterator) != KERN_SUCCESS) return result;
    while (io_registry_entry_t accelerator = IOIteratorNext(iterator)) {
        CFTypeRef stats = IORegistryEntryCreateCFProperty(accelerator, CFSTR("PerformanceStatistics"), kCFAllocatorDefault, 0);
        if (stats && CFGetTypeID(stats) == CFDictionaryGetTypeID()) {
            const auto dictionary = CFDictionaryRef(stats);
            const double util = numberIn(dictionary, "Device Utilization %");
            if (util >= 0) {
                double used = numberIn(dictionary, "In use system memory");
                if (used < 0) used = numberIn(dictionary, "vramUsedBytes");
                double total = numberIn(dictionary, "vramFreeBytes");
                total = total >= 0 && used >= 0 ? total + used : 0;
                result.append(QVariantMap{{"name", modelOf(accelerator)}, {"util", util},
                    {"memUsedMiB", used > 0 ? used / 1048576 : 0.0}, {"memTotalMiB", total / 1048576}});
            }
        }
        if (stats) CFRelease(stats);
        IOObjectRelease(accelerator);
    }
    IOObjectRelease(iterator);
    return result;
}

bool Sys::Native::usesNvidiaSmi() { return false; }
