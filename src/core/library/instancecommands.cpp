#include "instancemodel.h"
#include "../prism/launcherbridge.h"
#include "../prism/paths.h"
#include "../prism/configreader.h"
#include "../prism/configwriter.h"
#include <QDesktopServices>
#include <QFileInfo>
#include <QRegularExpression>

bool InstanceModel::renameInstance(const QString &id, const QString &name, const QString &originalName)
{
    const auto fail = [this](const QString &message) { emit errorOccurred(message); return false; };
    const QString trimmed = name.trimmed();
    if (trimmed.isEmpty() || name.contains(QRegularExpression("[\\x{0000}-\\x{001f}\\x{007f}]")))
        return fail("Enter a name on a single line.");
    const Instance *instance = find(id);
    if (!instance) return fail("This instance is no longer available.");
    const QString path = instance->path + "/instance.cfg";
    if (Prism::readConfig(path).value("name", id) != originalName)
        return fail("The instance name changed. Close this box and try again.");
    QString error;
    if (!Prism::writeConfig(path, {{"name", trimmed}}, &error)) return fail(error);
    reload();
    return true;
}

bool InstanceModel::launch(const QString &instanceId)
{
    const Instance *inst = find(instanceId);
    if (!inst || !QFileInfo::exists(inst->path + "/instance.cfg")) {
        emit errorOccurred(QStringLiteral("This instance is no longer available. Refresh the library."));
        return false;
    }
    if (refuseIfRunning(*inst)) return false;
    return startPrism({"--launch", instanceId});
}

// Prism cannot run one instance twice: a second launch only opens its console, so it is
// stopped here with a clear message instead of being handed to Prism.
bool InstanceModel::refuseIfRunning(const Instance &inst)
{
    if (!Prism::instanceRunning(inst.path)) return false;
    emit errorOccurred(inst.name + " is already running. Close it first, or use Play as another account.");
    return true;
}

bool InstanceModel::isRunning(const QString &instanceId) const
{
    const Instance *inst = find(instanceId);
    return inst && Prism::instanceRunning(inst->path);
}

bool InstanceModel::openFolder(const QString &instanceId)
{
    if (const Instance *inst = find(instanceId); inst && QFileInfo(inst->path).isDir()) {
        if (QDesktopServices::openUrl(QUrl::fromLocalFile(inst->path)))
            return true;
        emit errorOccurred(QStringLiteral("Could not open the instance folder."));
    } else {
        emit errorOccurred(QStringLiteral("This instance folder is no longer available."));
    }
    return false;
}

bool InstanceModel::openPrism()
{
    // Normal startup also opens an existing Prism window, and works on versions
    // predating the --show-window option added for command-line game launches.
    return startPrism({});
}

bool InstanceModel::launchWorld(const QString &id, const QString &world)
{
    const Instance *inst = find(id);
    if (!inst || world.isEmpty() || QFileInfo(world).fileName() != world
        || !QFileInfo::exists(Prism::gameDir(inst->path) + "/saves/" + world + "/level.dat")) return false;
    if (refuseIfRunning(*inst)) return false;
    return startPrism({"--launch", id, "--world", world});
}

bool InstanceModel::launchServer(const QString &id, const QString &address)
{
    // Only plain host[:port] values reach Prism's command line.
    static const QRegularExpression allowed(QStringLiteral(R"(^[A-Za-z0-9._\-]+(:\d{1,5})?$|^\[[0-9A-Fa-f:.]+\](:\d{1,5})?$)"));
    if (!find(id) || address.size() > 255 || !allowed.match(address).hasMatch()) return false;
    if (refuseIfRunning(*find(id))) return false;
    return startPrism({"--launch", id, "--server", address});
}

bool InstanceModel::importPack(const QUrl &url)
{
    if (!url.isLocalFile() || !QFileInfo(url.toLocalFile()).isFile()
        || (!url.toLocalFile().endsWith(".mrpack", Qt::CaseInsensitive) && !url.toLocalFile().endsWith(".zip", Qt::CaseInsensitive))) {
        emit errorOccurred("Choose a .mrpack or .zip modpack file.");
        return false;
    }
    return startPrism({"--import", url.toString()});
}

bool InstanceModel::editInPrism(const QString &instanceId)
{
    if (!find(instanceId))
        return false;
    return startPrism({"--show", instanceId});
}

bool InstanceModel::openModsFolder(const QString &instanceId)
{
    const Instance *inst = find(instanceId);
    if (inst && QFileInfo(Prism::gameDir(inst->path) + "/mods").isDir()
        && QDesktopServices::openUrl(QUrl::fromLocalFile(Prism::gameDir(inst->path) + "/mods")))
        return true;
    emit errorOccurred(QStringLiteral("No mods folder is available for this instance."));
    return false;
}

bool InstanceModel::startPrism(const QStringList &arguments)
{
    QString error;
    if (Prism::startLauncher(m_dataDir, arguments, &error)) return true;
    emit errorOccurred(error);
    return false;
}

bool InstanceModel::setPrismConsole(bool allow)
{
    const QString path = m_dataDir + "/prismlauncher.cfg";
    const auto current = Prism::readConfig(path);
    // Prism's own defaults when allowed: no console while playing, shown after a crash.
    const QVariantMap wanted{{"ShowConsole", "false"}, {"ShowConsoleOnError", allow ? "true" : "false"}};
    bool same = true;
    for (auto it = wanted.cbegin(); it != wanted.cend(); ++it)
        same &= current.value(it.key()).compare(it.value().toString(), Qt::CaseInsensitive) == 0;
    if (same || !QFileInfo::exists(path)) return true;
    QString error;
    if (Prism::writeConfig(path, wanted, &error)) return true;
    emit errorOccurred(error);
    return false;
}

void InstanceModel::setPrismProgram(const QString &path)
{
    Prism::setLauncherProgram(path);
}

QString InstanceModel::prismProgram() const
{
    return Prism::launcherProgram();
}
