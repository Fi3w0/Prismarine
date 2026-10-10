#include "crashanalyzer.h"
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QRegularExpression>
#include <QSet>
#include <algorithm>

namespace {
constexpr qint64 MaxRead = 4 * 1024 * 1024;

// Loader and runtime modules that appear in every stack trace and are never the culprit.
const QSet<QString> &platformModules()
{
    static const QSet<QString> names{"minecraft", "neoforge", "forge", "fml", "fml_loader", "fmlloader", "fmlcore", "javafmllanguage",
                                     "mixinextras", "mixin", "fabricloader", "fabric-loader", "quilt_loader", "java", "jdk", "lwjgl"};
    return names;
}

QVariantMap finding(const QString &kind, const QString &title, const QString &detail, const QStringList &mods = {},
                    const QString &action = {}, const QString &query = {})
{
    return {{"kind", kind}, {"title", title}, {"detail", detail}, {"mods", mods}, {"action", action}, {"query", query}};
}

QString readTail(const QString &path)
{
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return {};
    if (file.size() > MaxRead) file.seek(file.size() - MaxRead);
    return QString::fromUtf8(file.readAll());
}

// The first mod in a stack trace, from NeoForge "TRANSFORMER/id@version" frames or jar names.
QString firstModFrame(const QString &text, int from)
{
    static const QRegularExpression frame(QStringLiteral(R"(TRANSFORMER/([a-z0-9_.\-]+)@)"));
    auto it = frame.globalMatch(text, from);
    int checked = 0;
    while (it.hasNext() && checked++ < 60) {
        const QString id = it.next().captured(1);
        if (!platformModules().contains(id)) return id;
    }
    return {};
}

QStringList lineBlock(const QString &text, int from, const QRegularExpression &line, int limit = 12)
{
    QStringList lines;
    const QStringList after = text.mid(from).split('\n').mid(1, 40);
    for (const QString &raw : after) {
        const QString trimmed = raw.trimmed();
        if (trimmed.isEmpty()) { if (!lines.isEmpty()) break; continue; }
        if (!line.match(trimmed).hasMatch()) { if (!lines.isEmpty()) break; continue; }
        lines.append(trimmed);
        if (lines.size() >= limit) break;
    }
    return lines;
}
}

bool CrashAnalyzer::crashed(const QString &text)
{
    static const QRegularExpression markers(QStringLiteral(
        R"(---- Minecraft Crash Report ----|#@!@# Game crashed!|Incompatible mods found!|Missing or unsupported mandatory dependencies|Mod loading has failed|Exception in thread "main"|java\.lang\.OutOfMemoryError|UnsupportedClassVersionError|Failed to start the minecraft server|Encountered an unexpected exception)"));
    return markers.match(text).hasMatch();
}

QVariantList CrashAnalyzer::analyze(const QString &text)
{
    QVariantList findings;
    QSet<QString> seen;
    const auto add = [&](const QVariantMap &item) {
        const QString key = item.value("kind").toString() + item.value("mods").toStringList().join(',') + item.value("detail").toString().left(80);
        if (!seen.contains(key)) { seen.insert(key); findings.append(item); }
    };

    // Java version: class file version N needs Java N - 44.
    static const QRegularExpression classVersion(QStringLiteral(R"(UnsupportedClassVersionError.*?class file version (\d+)(?:\.\d+)?.*?up to (\d+))"));
    if (const auto m = classVersion.match(text); m.hasMatch()) {
        const int needed = m.captured(1).toInt() - 44, running = m.captured(2).toInt() - 44;
        add(finding("java", "This needs Java " + QString::number(needed),
                    "A mod or the game was built for Java " + QString::number(needed) + ", but Java " + QString::number(running)
                        + " is running. Pick Java " + QString::number(needed) + " (or let Prism choose automatically) in the instance settings.",
                    {}, "settings"));
    }

    if (text.contains("java.lang.OutOfMemoryError"))
        add(finding("memory", "Minecraft ran out of memory",
                    "The game needed more memory than it was allowed. Raise Max memory in Quick settings; large packs usually need 6–8 GiB.",
                    {}, "settings"));

    // Fabric / Quilt: "Incompatible mods found!" followed by "- Mod 'A' (a) ... requires ..." lines.
    if (const int at = int(text.indexOf("Incompatible mods found!")); at >= 0) {
        static const QRegularExpression item(QStringLiteral(R"(^[-\t ]*(?:- )?(Mod|Install|Remove|Replace|Upgrade|Downgrade).*)"));
        const QStringList lines = lineBlock(text, at, item);
        static const QRegularExpression ids(QStringLiteral(R"(\(([a-z0-9_\-]+)\))"));
        QStringList mods;
        for (const QString &line : lines)
            for (auto it = ids.globalMatch(line); it.hasNext();) {
                const QString id = it.next().captured(1);
                if (!mods.contains(id)) mods.append(id);
            }
        QString detail = lines.isEmpty() ? QStringLiteral("Some installed mods do not work together.") : lines.join('\n');
        detail.replace(QRegularExpression(QStringLiteral("(^|\n)- ")), QStringLiteral("\\1"));
        add(finding("incompatible", "Some mods need different versions", detail, mods, "mods"));
    }

    // NeoForge / Forge: "Mod ID: 'x', Requested by: 'y', Expected range: '[..]', Actual version: '[MISSING]'".
    static const QRegularExpression missing(QStringLiteral(R"(Mod ID: '([^']+)', Requested by: '([^']+)', Expected range: '([^']*)', Actual version: '([^']*)')"));
    for (auto it = missing.globalMatch(text); it.hasNext();) {
        const auto m = it.next();
        const bool absent = m.captured(4).contains("MISSING", Qt::CaseInsensitive);
        add(finding("dependency", absent ? m.captured(2) + " needs " + m.captured(1) : m.captured(2) + " needs another version of " + m.captured(1),
                    absent ? "Install " + m.captured(1) + " (" + m.captured(3) + ") for this Minecraft version."
                           : "Installed " + m.captured(1) + " " + m.captured(4) + ", but " + m.captured(2) + " expects " + m.captured(3) + ".",
                    {m.captured(1), m.captured(2)}, "browse", m.captured(1)));
    }

    // NeoForge "Failure message" lines: "Mod chipped requires athena 4.0.0 or above".
    QSet<QString> explained;
    static const QRegularExpression dependsOn(QStringLiteral(R"(Failure message: Mod ([a-z0-9_\-]+) requires ([a-z0-9_\-]+)(?: ([^\n]+))?)"));
    for (auto it = dependsOn.globalMatch(text); it.hasNext();) {
        const auto m = it.next();
        const QString range = m.captured(3).trimmed();
        explained.insert(m.captured(1));
        add(finding("dependency", m.captured(1) + " needs " + m.captured(2),
                    "Install " + m.captured(2) + (range.isEmpty() || range == "any" ? QString() : " (" + range + ")") + " for this Minecraft version.",
                    {m.captured(2), m.captured(1)}, "browse", m.captured(2)));
    }
    static const QRegularExpression provider(QStringLiteral(R"(Mod File (?:mods/)?([^\s]+) needs language provider ([a-z0-9_\-]+):([^\s]+))"));
    for (auto it = provider.globalMatch(text); it.hasNext();) {
        const auto m = it.next();
        add(finding("dependency", m.captured(1) + " needs " + m.captured(2),
                    "This mod is written in another language and needs " + m.captured(2) + " " + m.captured(3) + " or newer installed.",
                    {m.captured(2)}, "browse", m.captured(2)));
    }

    static const QRegularExpression duplicate(QStringLiteral(R"((?:Found duplicate mods|Duplicate mods? found|DuplicateModsFoundException|Mod ID '([a-z0-9_\-]+)' (?:is duplicated|has been duplicated)))"));
    if (const auto m = duplicate.match(text); m.hasMatch())
        add(finding("duplicate", "The same mod is installed twice",
                    m.captured(1).isEmpty() ? QStringLiteral("Two files provide the same mod. Keep the newest and remove the other in the Mods tab.")
                                            : "Two files provide " + m.captured(1) + ". Keep the newest and remove the other in the Mods tab.",
                    m.captured(1).isEmpty() ? QStringList() : QStringList{m.captured(1)}, "mods"));

    // Mixin failures name the mod that owns the mixin config, and often the mod it patches.
    static const QRegularExpression mixin(QStringLiteral(R"((?:Mixin \[|in |from )([a-z0-9_\-]+)\.mixins?\.json:([A-Za-z0-9_$.]+)[^\n]*?from mod ([a-z0-9_\-]+))"));
    static const QRegularExpression loadingIssue(QStringLiteral(R"(-- Mod loading issue for: ([a-z0-9_\-]+) --)"));
    QStringList failingMods;
    for (auto it = loadingIssue.globalMatch(text); it.hasNext();) {
        const QString id = it.next().captured(1);
        if (!failingMods.contains(id) && !explained.contains(id)) failingMods.append(id);
    }
    if (const auto m = mixin.match(text); m.hasMatch()) {
        const QString owner = m.captured(3);
        QStringList mods{owner};
        for (const QString &id : failingMods) if (!mods.contains(id)) mods.append(id);
        const QString target = mods.size() > 1 ? mods.at(1) : QString();
        add(finding("mixin", owner + " could not patch " + (target.isEmpty() ? QStringLiteral("the game") : target),
                    "Its mixin " + m.captured(2) + " failed to apply. This usually means " + owner
                        + (target.isEmpty() ? QStringLiteral(" does not match this Minecraft or loader version.")
                                            : " and " + target + " are versions that do not fit together. Update both, or disable " + owner + "."),
                    mods, "mods"));
    } else if (!failingMods.isEmpty()) {
        add(finding("loading", failingMods.join(", ") + (failingMods.size() == 1 ? " failed to load" : " failed to load"),
                    "The loader stopped while starting these mods. Check for updates or disable them in the Mods tab.", failingMods, "mods"));
    }

    // A class that is not there: one mod calls into another mod that is missing or the wrong version.
    static const QRegularExpression missingClass(QStringLiteral(R"((?:NoClassDefFoundError|ClassNotFoundException): ([A-Za-z0-9_$/.]+))"));
    if (const auto m = missingClass.match(text); m.hasMatch()) {
        const QString className = m.captured(1).replace('/', '.');
        const QString culprit = firstModFrame(text, int(m.capturedEnd()));
        const QStringList parts = className.split('.');
        // A loader or game class that is gone means the mod targets another version, not another mod.
        static const QStringList platformPackages{"net.neoforged.", "net.minecraftforge.", "net.fabricmc.", "org.quiltmc.", "net.minecraft.", "com.mojang."};
        const bool platform = std::any_of(platformPackages.begin(), platformPackages.end(), [&](const QString &p) { return className.startsWith(p); });
        if (platform) {
            add(finding("version", (culprit.isEmpty() ? QStringLiteral("A mod") : culprit) + " was made for a different game or loader version",
                        "It uses " + parts.constLast() + ", which this version of " + (className.startsWith("net.minecraft.") || className.startsWith("com.mojang.") ? "Minecraft" : "the mod loader")
                            + " does not have. Get the build of " + (culprit.isEmpty() ? QStringLiteral("that mod") : culprit) + " for this version, or disable it.",
                        culprit.isEmpty() ? QStringList() : QStringList{culprit}, "mods"));
        } else {
            // Package names usually carry the missing mod's name (shcm.shsupercm.fabric.citresewn → citresewn).
            QString hint;
            for (int i = parts.size() - 2; i >= 0 && hint.isEmpty(); --i) {
                const QString part = parts.at(i).toLower();
                if (part.size() > 3 && !QStringList{"fabric", "forge", "neoforge", "common", "client", "config", "mixin", "impl", "core", "util", "event", "events",
                                                     "compat", "integration", "gui", "screen", "render", "network", "world", "data", "registry", "init"}.contains(part))
                    hint = part;
            }
            add(finding("class", (culprit.isEmpty() ? QStringLiteral("A mod") : culprit) + " expected a mod that is not installed",
                        "It tried to use " + parts.constLast() + (hint.isEmpty() ? QString() : " from " + hint)
                            + ". Install that mod, update " + (culprit.isEmpty() ? QStringLiteral("the mod") : culprit)
                            + ", or disable it.",
                        culprit.isEmpty() ? QStringList() : QStringList{culprit}, hint.isEmpty() ? "mods" : "browse", hint));
        }
    }

    static const QRegularExpression graphics(QStringLiteral(R"(GLFW error 65542|Pixel format not accelerated|WGL: The driver does not appear to support OpenGL|No OpenGL context|GLX: Failed to create context|Couldn't set pixel format)"));
    if (graphics.match(text).hasMatch())
        add(finding("graphics", "The graphics driver refused to start OpenGL",
                    "Update your graphics driver. On laptops, make sure Minecraft runs on the dedicated GPU.", {}, ""));

    // Forge/NeoForge/Fabric list "Suspected Mod(s)" in crash reports.
    static const QRegularExpression suspected(QStringLiteral(R"(Suspected Mods?(?:\(s\))?:\s*\n((?:[ \t]+[^\n]+\n)+))"));
    if (const auto m = suspected.match(text); m.hasMatch() && !m.captured(1).contains("NONE")) {
        static const QRegularExpression entry(QStringLiteral(R"(\(([a-z0-9_\-]+)\))"));
        QStringList mods;
        for (auto it = entry.globalMatch(m.captured(1)); it.hasNext();) mods.append(it.next().captured(1));
        if (!mods.isEmpty())
            add(finding("suspected", "The crash report suspects " + mods.join(", "),
                        "Minecraft traced the crash to these mods. Update or disable them, then try again.", mods, "mods"));
    }

    // Nothing specific matched: still name the description and the first mod in the stack.
    if (findings.isEmpty() && crashed(text)) {
        static const QRegularExpression description(QStringLiteral(R"(Description: ([^\n]+))"));
        const auto d = description.match(text);
        const QString culprit = firstModFrame(text, 0);
        add(finding("unknown", d.hasMatch() ? "Crashed: " + d.captured(1).trimmed() : QStringLiteral("The game crashed"),
                    culprit.isEmpty() ? QStringLiteral("No common cause was found. Share the log to ask for help.")
                                      : "The first mod in the stack trace is " + culprit + ". Updating or disabling it is a good first test.",
                    culprit.isEmpty() ? QStringList() : QStringList{culprit}, culprit.isEmpty() ? "" : "mods"));
    }
    return findings;
}

QString CrashAnalyzer::collect(const QString &gameDir, qint64 sinceMs, QString *reportPath)
{
    QString text;
    const QFileInfo log(gameDir + "/logs/latest.log");
    const bool logCurrent = log.exists() && (!sinceMs || log.lastModified().toMSecsSinceEpoch() >= sinceMs - 2000);
    if (logCurrent) text = readTail(log.filePath());
    const QFileInfoList reports = QDir(gameDir + "/crash-reports").entryInfoList({"crash-*.txt"}, QDir::Files, QDir::Time);
    // A report belongs to the logged session only if the log stopped right after it was written;
    // an older report would blame a crash that the last session never had.
    const qint64 reportMs = reports.isEmpty() ? 0 : reports.first().lastModified().toMSecsSinceEpoch();
    const bool sameSession = logCurrent ? qAbs(log.lastModified().toMSecsSinceEpoch() - reportMs) < 120000 : !log.exists();
    if (!reports.isEmpty() && sameSession && (!sinceMs || reportMs >= sinceMs - 2000)) {
        if (reportPath) *reportPath = reports.first().filePath();
        text += "\n" + readTail(reports.first().filePath());
    }
    return text;
}
