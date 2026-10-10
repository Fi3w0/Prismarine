#include "launcherbridge.h"
#include <QDir>
#include <QProcess>
#include <QCoreApplication>
#include <QFileInfo>
#include <QStandardPaths>
#include <QSettings>
#include <QUrl>

#include "paths.h"

namespace {
QString chosenProgram;
qint64 startedLauncher = 0;

#ifdef Q_OS_LINUX
const QStringList snapNames{"prismlauncher-alpo", "prismlauncher"};
bool snapExecutable(const QString &program);

QString snapProgram(const QString &name)
{
    for (const QString &command : {name + ".prismlauncher", name}) {
        const QString absolute = "/snap/bin/" + command;
        if (QFileInfo(absolute).isExecutable()) return absolute;
        const QString alternate = "/var/lib/snapd/snap/bin/" + command;
        if (QFileInfo(alternate).isExecutable()) return alternate;
        const QString onPath = QStandardPaths::findExecutable(command);
        if (!onPath.isEmpty() && (command != "prismlauncher" || snapExecutable(onPath))) return onPath;
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
        || QFileInfo(program).fileName().startsWith("prismlauncher-alpo")
        || QFileInfo(program).symLinkTarget().endsWith("/snap");
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
    if (const QUrl url(chosenProgram); url.isLocalFile()) chosenProgram = url.toLocalFile();
#ifdef Q_OS_WIN
    chosenProgram = QDir::fromNativeSeparators(chosenProgram);
    // Repair paths stored by the old QML file picker (/C:/... instead of C:/...).
    if (chosenProgram.size() > 3 && chosenProgram[0] == '/' && chosenProgram[1].isLetter() && chosenProgram[2] == ':')
        chosenProgram.remove(0, 1);
#endif
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
    // Prism's installer remembers custom locations here, even when it is not on PATH.
    for (const QString &root : {QString("HKEY_CURRENT_USER\\Software\\PrismLauncher"),
                               QString("HKEY_LOCAL_MACHINE\\Software\\PrismLauncher"),
                               QString("HKEY_LOCAL_MACHINE\\Software\\WOW6432Node\\PrismLauncher")}) {
        const QString directory = QSettings(root, QSettings::NativeFormat).value("InstallDir").toString();
        if (!directory.isEmpty()) candidates << QDir::fromNativeSeparators(directory) + "/prismlauncher.exe";
    }
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
    // Only the quiet plugin belongs on Prism's search path. Sharing our whole
    // Qt plugin folder can replace Prism's TLS/platform plugins with incompatible ones.
    for (const QString &dir : {app + "/prism-plugins", app + "/../PlugIns/prismarine", app + "/../lib/prismarine/plugins"}) {
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
    QProcessEnvironment env = QProcessEnvironment::systemEnvironment();
    // Prism must discover the plugins and QML modules shipped with its own Qt.
    // These overrides commonly come from an AppImage or development environment.
    for (const char *variable : {"QT_PLUGIN_PATH", "QT_QPA_PLATFORM_PLUGIN_PATH", "QML_IMPORT_PATH", "QML2_IMPORT_PATH"})
        env.remove(variable);
    const QString plugins = quietPluginDir();
    // Explicit editing/importing must show Prism's windows. Only game launches are quiet.
    if (!sandboxed && arguments.contains("--launch") && !arguments.contains("--show-window") && !plugins.isEmpty()) {
        // Prism keeps the isolated plugin path out of the game's environment.
        env.insert("QT_PLUGIN_PATH", plugins);
        const QString generic = env.value("QT_QPA_GENERIC_PLUGINS");
        env.insert("QT_QPA_GENERIC_PLUGINS", generic.isEmpty() ? "prismarinequiet" : generic + ",prismarinequiet");
    }
    process.setProcessEnvironment(env);
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
    if (!alreadyRunning && !sandboxed && arguments.contains("--launch")) startedLauncher = pid;
    return true;
}
