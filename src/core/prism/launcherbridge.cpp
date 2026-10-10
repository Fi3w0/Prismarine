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

#ifdef Q_OS_LINUX
const QStringList snapNames{"prismlauncher-alpo", "prismlauncher"};

QString snapProgram(const QString &name)
{
    for (const QString &command : {name + ".prismlauncher", name}) {
        const QString onPath = QStandardPaths::findExecutable(command);
        if (!onPath.isEmpty()) return onPath;
        const QString absolute = "/snap/bin/" + command;
        if (QFileInfo(absolute).isExecutable()) return absolute;
    }
    return {};
}

bool flatpakInstalled(const QString &program)
{
    if (program.isEmpty()) return false;
    QProcess probe;
    probe.setProgram(program);
    probe.setArguments({"info", "org.prismlauncher.PrismLauncher"});
    probe.start();
    if (!probe.waitForFinished(2000)) {
        probe.kill();
        probe.waitForFinished(1000);
        return false;
    }
    return probe.exitStatus() == QProcess::NormalExit && probe.exitCode() == 0;
}

bool snapExecutable(const QString &program)
{
    return program.startsWith("/snap/bin/") || program.startsWith("/var/lib/snapd/snap/bin/")
        || QFileInfo(program).fileName().startsWith("prismlauncher-alpo");
}
#endif
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
               << QDir::homePath() + "/Applications/Prism Launcher.app/Contents/MacOS/prismlauncher"
               << "/Applications/PrismLauncher.app/Contents/MacOS/prismlauncher"
               << QDir::homePath() + "/Applications/PrismLauncher.app/Contents/MacOS/prismlauncher";
#else
    candidates << QDir::homePath() + "/.local/bin/prismlauncher"
               << QDir::homePath() + "/.nix-profile/bin/prismlauncher"
               << "/etc/profiles/per-user/" + qEnvironmentVariable("USER") + "/bin/prismlauncher"
               << "/run/current-system/sw/bin/prismlauncher"
               << "/usr/local/bin/prismlauncher" << "/usr/bin/prismlauncher";
#ifdef Q_OS_LINUX
    for (const QString &name : snapNames) {
        const QString program = snapProgram(name);
        if (!program.isEmpty()) candidates << program;
    }
    // Portable archives and AppImages in common user-managed locations.
    for (const QString &root : {QDir::homePath() + "/Applications", QDir::homePath() + "/AppImages",
                               QDir::homePath() + "/Downloads", QDir::homePath(), QString("/opt")}) {
        candidates << root + "/PrismLauncher/prismlauncher" << root + "/prismlauncher/prismlauncher";
        const QDir directory(root);
        for (const QString &name : directory.entryList({"PrismLauncher*.AppImage", "prismlauncher*.AppImage"}, QDir::Files, QDir::Name))
            candidates << directory.filePath(name);
    }
#endif
#endif
    for (const QString &candidate : candidates)
        if (QFileInfo(candidate).isFile() && QFileInfo(candidate).isExecutable()) return candidate;
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
    QString executable = launcherProgram();
    QStringList args;
    bool sandboxed = false;
#ifdef Q_OS_LINUX
    if (chosenProgram.isEmpty() || !QFileInfo(chosenProgram).isExecutable()) {
        const QString absoluteData = QDir::cleanPath(QDir(dataDir).absolutePath());
        const bool flatpakData = absoluteData.startsWith(QDir::homePath() + "/.var/app/org.prismlauncher.PrismLauncher/");
        const QString flatpak = QStandardPaths::findExecutable("flatpak");
        if (flatpakData || (executable.isEmpty() && flatpakInstalled(flatpak))) {
            executable = flatpak;
            args = {"run", "org.prismlauncher.PrismLauncher"};
            sandboxed = true;
        } else {
            // A data directory belonging to a Snap must launch that same Snap.
            for (const QString &name : snapNames) {
                if (absoluteData.startsWith(QDir::homePath() + "/snap/" + name + "/")) {
                    executable = snapProgram(name);
                    sandboxed = true;
                    break;
                }
            }
        }
    }
    sandboxed = sandboxed || snapExecutable(executable);
#endif
    args << "--dir" << dataDir;
    args.append(arguments);
    QProcess process;
    process.setProgram(executable);
    process.setArguments(args);
    const QString plugins = quietPluginDir();
    if (!sandboxed && !plugins.isEmpty()) {
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
    if (!alreadyRunning && !sandboxed) startedLauncher = pid;
    return true;
}
