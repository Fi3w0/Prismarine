#include "paths.h"
#include "../system/system.h"
#include "launcherbridge.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QStandardPaths>

namespace Prism {
QString findDataDir()
{
    // Portable Prism (portable.txt beside the program, e.g. the Windows zip or Scoop) keeps its data there.
    if (const QString program = launcherProgram(); !program.isEmpty()) {
        const QString beside = QFileInfo(program).absolutePath();
        if (QFileInfo::exists(beside + "/portable.txt")) return beside;
    }
    QStringList candidates;
#ifdef Q_OS_WIN
    // Prism uses the roaming profile on Windows: %APPDATA%\PrismLauncher.
    candidates.append(QDir::fromNativeSeparators(qEnvironmentVariable("APPDATA")) + "/PrismLauncher");
#endif
    // Linux/FreeBSD: ~/.local/share (or $XDG_DATA_HOME); macOS: ~/Library/Application Support.
    candidates.append(QStandardPaths::writableLocation(QStandardPaths::GenericDataLocation) + "/PrismLauncher");
#if defined(Q_OS_LINUX)
    candidates.append(QDir::homePath() + "/.var/app/org.prismlauncher.PrismLauncher/data/PrismLauncher");
    for (const QString &name : {QString("prismlauncher-alpo"), QString("prismlauncher")}) {
        const QString base = QDir::homePath() + "/snap/" + name;
        for (const QString &revision : {QString("current"), QString("common")}) {
            candidates << base + "/" + revision + "/.local/share/PrismLauncher"
                       << base + "/" + revision + "/PrismLauncher";
        }
    }
#endif
    for (const QString &dir : candidates) {
        if (QFileInfo::exists(dir + "/prismlauncher.cfg"))
            return dir;
    }
    return candidates.first();
}

QString gameDir(const QString &instancePath)
{
    for (const char *name : {"minecraft", ".minecraft"}) {
        const QString dir = instancePath + "/" + name;
        if (QFileInfo(dir).isDir())
            return dir;
    }
    return instancePath + "/minecraft";
}

}

QString Prism::contentDir(const QString &instancePath, const QString &type, const QString &world)
{
    if (instancePath.isEmpty()) return {};
    const QString game = gameDir(instancePath);
    QString path;
    if (type == "mod") path = game + "/mods";
    else if (type == "resourcepack") path = game + "/resourcepacks";
    else if (type == "shader") path = game + "/shaderpacks";
    else if (type == "datapack") {
        if (world.isEmpty() || world == "." || world == ".." || world.contains('/') || world.contains('\\') || world.contains(QChar(0))) return {};
        const QFileInfo folder(game + "/saves/" + world);
        if (folder.isSymLink() || !QFileInfo::exists(folder.filePath() + "/level.dat")
            || folder.canonicalFilePath() != QFileInfo(game + "/saves").canonicalFilePath() + "/" + world) return {};
        path = folder.filePath() + "/datapacks";
    } else return {};
    if (QFileInfo(path).isSymLink()) return {};
    return path;
}

bool Prism::instanceRunning(const QString &instancePath)
{
    const QString game = QFileInfo(gameDir(instancePath)).canonicalFilePath();
    for (const auto &process : Sys::processes(Sys::isJavaName))
        if (Sys::isJavaName(process.name) && !process.zombie && Sys::belongsToInstance(process, instancePath, game)) return true;
    return false;
}

bool Prism::launcherRunning()
{
    for (const auto &process : Sys::processes([](const QString &) { return false; }))
        if (Sys::isPrismName(process.name) && !process.zombie) return true;
    return false;
}
