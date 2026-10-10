#pragma once
#include <QString>
namespace Prism {
QString findDataDir();
bool instanceRunning(const QString &instancePath);
// True while a Prism Launcher window or process is open (Linux only).
bool launcherRunning();
QString contentDir(const QString &instancePath, const QString &type, const QString &world = {});
QString gameDir(const QString &instancePath);
}
