#include "launcherbridge.h"
#include <QDir>
#include <QProcess>
#include <QCoreApplication>
#include <QFileInfo>
#include <QStandardPaths>

#include "paths.h"

namespace {
QString chosenProgram;
qint64 startedLauncher = 0;
}

qint64 Prism::lastStartedLauncher()
{
    return startedLauncher;
}

void Prism::setLauncherProgram(const QString &path)
{
    chosenProgram = path.trimmed();
}

QString Prism::launcherProgram()
{
    if (!chosenProgram.isEmpty() && QFileInfo(chosenProgram).isExecutable()) return chosenProgram;
    QStringList candidates;
#ifdef Q_OS_WIN
    candidates.append(QCoreApplication::applicationDirPath() + "/prismlauncher.exe");
#else
    candidates.append(QCoreApplication::applicationDirPath() + "/prismlauncher");
#endif
    if (const QString onPath = QStandardPaths::findExecutable("prismlauncher"); !onPath.isEmpty()) candidates.append(onPath);
    // Where Prism's own installers put it.
#if defined(Q_OS_WIN)
    const auto env = [](const char *name) { return QDir::fromNativeSeparators(qEnvironmentVariable(name)); };
    candidates << env("LOCALAPPDATA") + "/Programs/PrismLauncher/prismlauncher.exe"
               << env("ProgramFiles") + "/PrismLauncher/prismlauncher.exe"
               << env("ProgramFiles(x86)") + "/PrismLauncher/prismlauncher.exe"
               << env("USERPROFILE") + "/scoop/apps/prismlauncher/current/prismlauncher.exe";
#elif defined(Q_OS_MACOS)
    candidates << "/Applications/Prism Launcher.app/Contents/MacOS/prismlauncher"
               << QDir::homePath() + "/Applications/Prism Launcher.app/Contents/MacOS/prismlauncher";
#else
    candidates << "/usr/local/bin/prismlauncher" << "/usr/bin/prismlauncher";
#endif
    for (const QString &candidate : candidates)
        if (QFileInfo(candidate).isExecutable()) return candidate;
    return {};
}

QString Prism::quietPluginDir()
{
    const QString app = QCoreApplication::applicationDirPath();
    // Build tree and Windows: beside the executable; macOS app bundle: Contents/PlugIns; installs: lib/.
    for (const QString &dir : {app + "/plugins", app + "/../PlugIns", app + "/../lib/prismarine/plugins"}) {
        if (!QDir(dir + "/generic").entryList({"*prismarinequiet*"}, QDir::Files).isEmpty())
            return QDir(dir).canonicalPath();
    }
    return {};
}

bool Prism::startLauncher(const QString &dataDir, const QStringList &arguments, QString *error)
{
#ifdef Q_OS_LINUX
    const bool flatpakData = dataDir.startsWith(QDir::homePath() + "/.var/app/org.prismlauncher.PrismLauncher/");
#else
    const bool flatpakData = false;
#endif
    QString executable = flatpakData ? QStandardPaths::findExecutable("flatpak") : launcherProgram();
    QStringList args;
    if (flatpakData || executable.isEmpty()) {
        // Without a Prism program, a Flatpak Prism is the last place to look (Linux only).
        executable = QStandardPaths::findExecutable("flatpak");
        args = {"run", "org.prismlauncher.PrismLauncher"};
    }
    args << "--dir" << dataDir;
    args.append(arguments);
    QProcess process;
    process.setProgram(executable);
    process.setArguments(args);
    const QString plugins = quietPluginDir();
    if (!flatpakData && !args.startsWith("run") && !plugins.isEmpty()) {
        // Added to whatever the user already set; Prism keeps these out of the game's environment.
        QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
        const QString pluginPath = env.value("QT_PLUGIN_PATH");
        env.insert("QT_PLUGIN_PATH", pluginPath.isEmpty() ? plugins : plugins + QDir::listSeparator() + pluginPath);
        const QString generic = env.value("QT_QPA_GENERIC_PLUGINS");
        env.insert("QT_QPA_GENERIC_PLUGINS", generic.isEmpty() ? "prismarinequiet" : generic + ",prismarinequiet");
        process.setProcessEnvironment(env);
    }
    // Prism writes its own log; its console output would only clutter Prismarine's.
    process.setStandardOutputFile(QProcess::nullDevice());
    process.setStandardErrorFile(QProcess::nullDevice());
    // Checked before starting: afterwards the new process itself counts as running.
    const bool alreadyRunning = Prism::launcherRunning();
    qint64 pid = 0;
    startedLauncher = 0;
    if (executable.isEmpty() || !process.startDetached(&pid)) {
        if (error) *error = "Could not start Prism Launcher. Check that it is installed.";
        return false;
    }
    // A Flatpak Prism runs behind `flatpak run`, whose process id is not Prism's.
    if (!alreadyRunning && !args.startsWith("run")) startedLauncher = pid;
    return true;
}
