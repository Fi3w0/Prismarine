// Linux: processes and load from /proc, AMD GPUs from /sys/class/drm, NVIDIA via nvidia-smi.
#include "native.h"
#include <QDir>
#include <QFile>
#include <QRegularExpression>

namespace {
QByteArray readFile(const QString &path)
{
    QFile file(path);
    return file.open(QIODevice::ReadOnly) ? file.readAll() : QByteArray();
}
}

bool Sys::Native::processesSupported() { return QDir("/proc/self").exists(); }
QList<Sys::Process> Sys::Native::processes(const std::function<bool(const QString &)> &wanted) { return ProcFs::processes("/proc", wanted); }
Sys::Process Sys::Native::process(qint64 pid) { return ProcFs::process("/proc", pid); }
Sys::CpuTimes Sys::Native::cpuTimes() { return ProcFs::cpuTimes("/proc"); }
Sys::Memory Sys::Native::memory() { return ProcFs::memory("/proc"); }
bool Sys::Native::usesNvidiaSmi() { return true; }

QVariantList Sys::Native::gpus(const QString &drmRoot)
{
    // amdgpu exposes load and VRAM in sysfs; other drivers (NVIDIA, most Intel) do not.
    const QString root = drmRoot.isEmpty() ? QStringLiteral("/sys/class/drm") : drmRoot;
    static const QRegularExpression cardName(QStringLiteral("^card\\d+$"));
    const QStringList cards = QDir(root).entryList({"card*"}, QDir::Dirs | QDir::System).filter(cardName);
    QStringList busyCards;
    for (const QString &card : cards)
        if (!readFile(root + "/" + card + "/device/gpu_busy_percent").isEmpty()) busyCards.append(card);
    QVariantList result;
    for (const QString &card : busyCards) {
        const QString device = root + "/" + card + "/device";
        const double vramMiB = readFile(device + "/mem_info_vram_total").trimmed().toDouble() / 1048576;
        const bool amd = readFile(device + "/vendor").trimmed() == "0x1002";
        // Integrated Radeons only get a small carve-out of system memory as VRAM.
        QString name = amd ? (vramMiB > 0 && vramMiB <= 1024 ? "AMD Radeon integrated" : "AMD Radeon") : "GPU";
        if (busyCards.size() > 1) name += " · " + card;
        result.append(QVariantMap{{"name", name}, {"util", readFile(device + "/gpu_busy_percent").trimmed().toDouble()},
            {"memUsedMiB", readFile(device + "/mem_info_vram_used").trimmed().toDouble() / 1048576}, {"memTotalMiB", vramMiB}});
    }
    return result;
}
