#pragma once
#include "system.h"

// Implemented once per operating system (system_<os>.cpp); system_common.cpp routes the
// public Sys:: calls here unless a test points them at a fake /proc tree.
namespace Sys::Native {
bool processesSupported();
QList<Process> processes(const std::function<bool(const QString &)> &wanted);
Process process(qint64 pid);
bool requestClose(qint64 pid);
bool terminate(qint64 pid);
CpuTimes cpuTimes();
Memory memory();
QVariantList gpus(const QString &drmRoot);
bool usesNvidiaSmi();
FileId fileId(const QString &path);
bool hardLink(const QString &existing, const QString &link);
bool replaceFile(const QString &from, const QString &to);
}
