#include "desktopintegration.h"
#include <QProcess>
#include <QStandardPaths>

namespace {
// Keys of Prismarine's rule. Match: window class contains "prismlauncher" (the Wayland
// app id is org.prismlauncher.PrismLauncher) and the title contains "Please wait".
// Rule value 3 means "apply initially", like a user-made rule: the window can still be restored.
const QList<QPair<QString, QString>> ruleKeys{
    {"Description", "Prismarine: keep Prism's \"Please wait\" window minimized"},
    {"wmclass", "prismlauncher"}, {"wmclassmatch", "2"},
    {"title", "Please wait"}, {"titlematch", "2"},
    {"minimize", "true"}, {"minimizerule", "3"},
    {"skiptaskbar", "true"}, {"skiptaskbarrule", "3"},
    {"skipswitcher", "true"}, {"skipswitcherrule", "3"},
};

QString tool(const char *name)
{
    return QStandardPaths::findExecutable(QString::fromLatin1(name));
}
}

DesktopIntegration::DesktopIntegration(QObject *parent, const QString &rulesFile, bool reloadKWin)
    : QObject(parent), m_file(rulesFile), m_reload(reloadKWin) {}

bool DesktopIntegration::kdeAvailable() const
{
    return qEnvironmentVariable("XDG_CURRENT_DESKTOP").contains("KDE", Qt::CaseInsensitive)
        && !tool("kreadconfig6").isEmpty() && !tool("kwriteconfig6").isEmpty();
}

QString DesktopIntegration::read(const QString &group, const QString &key) const
{
    QProcess process;
    process.start(tool("kreadconfig6"), {"--file", m_file, "--group", group, "--key", key});
    if (!process.waitForFinished(5000) || process.exitCode() != 0) return {};
    return QString::fromUtf8(process.readAllStandardOutput()).trimmed();
}

bool DesktopIntegration::write(const QString &group, const QString &key, const QString &value) const
{
    return QProcess::execute(tool("kwriteconfig6"), {"--file", m_file, "--group", group, "--key", key, value}) == 0;
}

bool DesktopIntegration::remove(const QString &group, const QString &key) const
{
    return QProcess::execute(tool("kwriteconfig6"), {"--file", m_file, "--group", group, "--key", key, "--delete"}) == 0;
}

QStringList DesktopIntegration::ruleIds() const
{
    QStringList ids = read("General", "rules").split(',', Qt::SkipEmptyParts);
    for (auto &id : ids) id = id.trimmed();
    return ids;
}

bool DesktopIntegration::hidePrismProgress() const
{
    return kdeAvailable() && ruleIds().contains(RuleId) && !read(RuleId, "wmclass").isEmpty();
}

bool DesktopIntegration::setHidePrismProgress(bool enabled)
{
    if (!kdeAvailable()) { emit errorOccurred("This needs KDE Plasma's window rules."); return false; }
    QStringList ids = ruleIds();
    bool ok = true;
    if (enabled) {
        for (const auto &[key, value] : ruleKeys) ok &= write(RuleId, key, value);
        if (!ids.contains(RuleId)) ids.append(RuleId);
    } else {
        for (const auto &pair : ruleKeys) ok &= remove(RuleId, pair.first);
        ids.removeAll(RuleId);
    }
    ok &= write("General", "rules", ids.join(','));
    ok &= write("General", "count", QString::number(ids.size()));
    // KWin picks up the change without logging out.
    if (m_reload) {
        const QString qdbus = !tool("qdbus6").isEmpty() ? tool("qdbus6") : tool("qdbus");
        if (!qdbus.isEmpty()) QProcess::execute(qdbus, {"org.kde.KWin", "/KWin", "reconfigure"});
    }
    if (!ok) emit errorOccurred("Could not update KDE's window rules.");
    emit changed();
    return ok;
}
