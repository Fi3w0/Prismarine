// Windows: processes through Toolhelp and the process APIs, load through GetSystemTimes and
// GlobalMemoryStatusEx, every GPU (NVIDIA, AMD, Intel) through the "GPU Engine" performance
// counters Task Manager uses, named via DXGI. Hard links are NTFS hard links.
#include "native.h"
#include <QDir>
#include <QHash>
#include <QFileInfo>
#ifndef NOMINMAX
#define NOMINMAX
#endif
#include <windows.h>
#include <dxgi.h>
#include <pdh.h>
#include <psapi.h>
#include <tlhelp32.h>
#include <vector>

namespace {
quint64 fileTime(const FILETIME &time)
{
    return (quint64(time.dwHighDateTime) << 32) | time.dwLowDateTime;
}

QString normalizedName(QString name)
{
    name = name.toLower();
    if (name.endsWith(".exe")) name.chop(4);
    return name;
}

// The command line of another process; needs Windows 8.1 or later (ProcessCommandLineInformation).
QString commandLine(HANDLE process)
{
    using Query = LONG(WINAPI *)(HANDLE, ULONG, PVOID, ULONG, PULONG);
    static const auto query = reinterpret_cast<Query>(GetProcAddress(GetModuleHandleW(L"ntdll.dll"), "NtQueryInformationProcess"));
    if (!query) return {};
    constexpr ULONG ProcessCommandLineInformation = 60;
    ULONG length = 0;
    query(process, ProcessCommandLineInformation, nullptr, 0, &length);
    if (length == 0 || length > 1 << 20) return {};
    std::vector<char> buffer(length);
    if (query(process, ProcessCommandLineInformation, buffer.data(), length, &length) < 0) return {};
    struct Unicode { USHORT Length, MaximumLength; PWSTR Buffer; };
    const auto *text = reinterpret_cast<const Unicode *>(buffer.data());
    return QString::fromWCharArray(text->Buffer, text->Length / sizeof(wchar_t));
}

void fillDetails(Sys::Process &p)
{
    HANDLE handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION | PROCESS_VM_READ, FALSE, DWORD(p.pid));
    if (!handle) handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, DWORD(p.pid));
    if (!handle) return;
    p.commandLine = commandLine(handle);
    FILETIME created, exited, kernel, user;
    if (GetProcessTimes(handle, &created, &exited, &kernel, &user)) p.cpuMs = qint64((fileTime(kernel) + fileTime(user)) / 10000);
    PROCESS_MEMORY_COUNTERS memory = {};
    if (GetProcessMemoryInfo(handle, &memory, sizeof(memory))) p.residentBytes = qint64(memory.WorkingSetSize);
    DWORD code = 0;
    if (GetExitCodeProcess(handle, &code) && code != STILL_ACTIVE) p.zombie = true;
    CloseHandle(handle);
}

// Collects the GPU counters between calls; utilisation is a rate, so the first sample is empty.
struct GpuCounters {
    PDH_HQUERY query = nullptr;
    PDH_HCOUNTER engine = nullptr, dedicated = nullptr;
    bool ready = false;
    GpuCounters()
    {
        if (PdhOpenQueryW(nullptr, 0, &query) != ERROR_SUCCESS) { query = nullptr; return; }
        PdhAddEnglishCounterW(query, L"\\GPU Engine(*engtype_3D)\\Utilization Percentage", 0, &engine);
        PdhAddEnglishCounterW(query, L"\\GPU Adapter Memory(*)\\Dedicated Usage", 0, &dedicated);
        PdhCollectQueryData(query);
    }
    ~GpuCounters() { if (query) PdhCloseQuery(query); }
    // Sum per adapter, keyed by the "luid_0x..._0x..." part of each instance name.
    QHash<QString, double> values(PDH_HCOUNTER counter)
    {
        QHash<QString, double> result;
        if (!counter) return result;
        DWORD size = 0, count = 0;
        PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, nullptr);
        if (!size) return result;
        std::vector<char> buffer(size);
        auto *items = reinterpret_cast<PDH_FMT_COUNTERVALUE_ITEM_W *>(buffer.data());
        if (PdhGetFormattedCounterArrayW(counter, PDH_FMT_DOUBLE, &size, &count, items) != ERROR_SUCCESS) return result;
        for (DWORD i = 0; i < count; ++i) {
            const QString name = QString::fromWCharArray(items[i].szName).toLower();
            const int at = name.indexOf("luid_");
            if (at < 0 || items[i].FmtValue.CStatus != ERROR_SUCCESS) continue;
            result[name.mid(at, 26)] += items[i].FmtValue.doubleValue;
        }
        return result;
    }
};
}

bool Sys::Native::processesSupported() { return true; }

QList<Sys::Process> Sys::Native::processes(const std::function<bool(const QString &)> &wanted)
{
    QList<Process> result;
    HANDLE snapshot = CreateToolhelp32Snapshot(TH32CS_SNAPPROCESS, 0);
    if (snapshot == INVALID_HANDLE_VALUE) return result;
    PROCESSENTRY32W entry = {};
    entry.dwSize = sizeof(entry);
    for (BOOL more = Process32FirstW(snapshot, &entry); more; more = Process32NextW(snapshot, &entry)) {
        if (entry.th32ProcessID == 0) continue;
        Process p;
        p.pid = entry.th32ProcessID;
        p.name = normalizedName(QString::fromWCharArray(entry.szExeFile));
        if (!wanted || wanted(p.name)) fillDetails(p);
        result.append(p);
    }
    CloseHandle(snapshot);
    return result;
}

Sys::Process Sys::Native::process(qint64 pid)
{
    HANDLE handle = OpenProcess(PROCESS_QUERY_LIMITED_INFORMATION, FALSE, DWORD(pid));
    if (!handle) return {};
    DWORD code = 0;
    const bool alive = GetExitCodeProcess(handle, &code) && code == STILL_ACTIVE;
    wchar_t path[MAX_PATH] = {};
    DWORD length = MAX_PATH;
    const bool named = QueryFullProcessImageNameW(handle, 0, path, &length);
    CloseHandle(handle);
    if (!alive) return {};
    Process p;
    p.pid = pid;
    if (named) p.name = normalizedName(QFileInfo(QString::fromWCharArray(path, int(length))).fileName());
    fillDetails(p);
    return p;
}

namespace {
BOOL CALLBACK closeWindowsOf(HWND window, LPARAM parameter)
{
    auto *target = reinterpret_cast<std::pair<DWORD, bool> *>(parameter);
    DWORD owner = 0;
    GetWindowThreadProcessId(window, &owner);
    if (owner == target->first && IsWindowVisible(window) && !GetWindow(window, GW_OWNER)) {
        PostMessageW(window, WM_CLOSE, 0, 0);
        target->second = true;
    }
    return TRUE;
}
}

bool Sys::Native::requestClose(qint64 pid)
{
    // Like clicking the window's close button, so Minecraft saves and quits normally.
    std::pair<DWORD, bool> target{DWORD(pid), false};
    EnumWindows(closeWindowsOf, reinterpret_cast<LPARAM>(&target));
    return target.second;
}

bool Sys::Native::terminate(qint64 pid)
{
    HANDLE handle = OpenProcess(PROCESS_TERMINATE, FALSE, DWORD(pid));
    if (!handle) return false;
    const bool done = TerminateProcess(handle, 1);
    CloseHandle(handle);
    return done;
}

Sys::CpuTimes Sys::Native::cpuTimes()
{
    FILETIME idle, kernel, user;
    if (!GetSystemTimes(&idle, &kernel, &user)) return {};
    CpuTimes times;
    // Kernel time includes idle time.
    times.total = fileTime(kernel) + fileTime(user);
    times.busy = times.total - fileTime(idle);
    times.valid = true;
    return times;
}

Sys::Memory Sys::Native::memory()
{
    MEMORYSTATUSEX status = {};
    status.dwLength = sizeof(status);
    if (!GlobalMemoryStatusEx(&status)) return {};
    return {double(status.ullTotalPhys) / 1048576, double(status.ullAvailPhys) / 1048576};
}

QVariantList Sys::Native::gpus(const QString &)
{
    static GpuCounters counters;
    QVariantList result;
    if (!counters.query || PdhCollectQueryData(counters.query) != ERROR_SUCCESS) return result;
    const auto load = counters.values(counters.engine);
    const auto used = counters.values(counters.dedicated);
    IDXGIFactory1 *factory = nullptr;
    if (FAILED(CreateDXGIFactory1(__uuidof(IDXGIFactory1), reinterpret_cast<void **>(&factory)))) return result;
    IDXGIAdapter1 *adapter = nullptr;
    for (UINT i = 0; factory->EnumAdapters1(i, &adapter) != DXGI_ERROR_NOT_FOUND; ++i) {
        DXGI_ADAPTER_DESC1 desc = {};
        if (SUCCEEDED(adapter->GetDesc1(&desc)) && !(desc.Flags & DXGI_ADAPTER_FLAG_SOFTWARE)) {
            const QString luid = QString("luid_0x%1_0x%2").arg(quint32(desc.AdapterLuid.HighPart), 8, 16, QChar('0'))
                                     .arg(quint32(desc.AdapterLuid.LowPart), 8, 16, QChar('0')).toLower();
            result.append(QVariantMap{{"name", QString::fromWCharArray(desc.Description).trimmed()},
                {"util", qBound(0.0, load.value(luid), 100.0)}, {"memUsedMiB", used.value(luid) / 1048576},
                {"memTotalMiB", double(desc.DedicatedVideoMemory) / 1048576}});
        }
        adapter->Release();
    }
    factory->Release();
    return result;
}

bool Sys::Native::usesNvidiaSmi() { return false; }

Sys::FileId Sys::Native::fileId(const QString &path)
{
    HANDLE file = CreateFileW(reinterpret_cast<const wchar_t *>(QDir::toNativeSeparators(path).utf16()), 0,
                              FILE_SHARE_READ | FILE_SHARE_WRITE | FILE_SHARE_DELETE, nullptr, OPEN_EXISTING, FILE_FLAG_BACKUP_SEMANTICS, nullptr);
    if (file == INVALID_HANDLE_VALUE) return {};
    BY_HANDLE_FILE_INFORMATION info = {};
    const bool ok = GetFileInformationByHandle(file, &info);
    CloseHandle(file);
    if (!ok) return {};
    return {info.dwVolumeSerialNumber, (quint64(info.nFileIndexHigh) << 32) | info.nFileIndexLow, info.nNumberOfLinks, true};
}

bool Sys::Native::hardLink(const QString &existing, const QString &link)
{
    return CreateHardLinkW(reinterpret_cast<const wchar_t *>(QDir::toNativeSeparators(link).utf16()),
                           reinterpret_cast<const wchar_t *>(QDir::toNativeSeparators(existing).utf16()), nullptr);
}

bool Sys::Native::replaceFile(const QString &from, const QString &to)
{
    return MoveFileExW(reinterpret_cast<const wchar_t *>(QDir::toNativeSeparators(from).utf16()),
                       reinterpret_cast<const wchar_t *>(QDir::toNativeSeparators(to).utf16()), MOVEFILE_REPLACE_EXISTING);
}
