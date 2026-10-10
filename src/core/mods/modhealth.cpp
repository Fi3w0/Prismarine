#include "modhealth.h"
#include "archivereader.h"
#include "../prism/paths.h"
#include <QDir>
#include <QFutureWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSet>
#include <QtConcurrent>

namespace {
const QStringList metadataNames{"fabric.mod.json", "quilt.mod.json", "META-INF/mods.toml", "META-INF/neoforge.mods.toml"};
// Provided by the game, the loader or the JVM rather than by a mod jar.
const QSet<QString> builtIn{"minecraft", "java", "fabricloader", "fabric-loader", "quilt_loader", "forge", "neoforge",
                            "javafml", "lowcodefml", "mixin", "quilt_base"};

struct Mod {
    QString fileName, name;
    bool enabled = true;
    QStringList loaders;    // every loader the jar declares metadata for
    QStringList ids;        // primary ids, used for duplicate detection
    QSet<QString> provides; // ids, aliases and ids of nested jars
    QStringList depends, breaks, discouraged;
};

struct TomlBlock { QString header; QHash<QString, QString> values; };

// Enough TOML for mods.toml: [[array]] tables with key = "string" | bool | number.
QVector<TomlBlock> tomlBlocks(const QString &text)
{
    QVector<TomlBlock> blocks{{}};
    static const QRegularExpression header(R"(^\s*\[\[\s*([^\]]+?)\s*\]\]\s*$)");
    static const QRegularExpression pair(R"re(^\s*([A-Za-z0-9_.-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^#\s]+)))re");
    for (const QString &line : text.split('\n')) {
        if (const auto match = header.match(line); match.hasMatch()) { blocks.append({match.captured(1), {}}); continue; }
        if (const auto match = pair.match(line); match.hasMatch()) {
            const QString value = !match.captured(2).isNull() ? match.captured(2) : !match.captured(3).isNull() ? match.captured(3) : match.captured(4);
            blocks.last().values.insert(match.captured(1), value);
        }
    }
    return blocks;
}

QStringList jsonKeys(const QJsonValue &value)
{
    QStringList keys;
    if (value.isObject()) keys = value.toObject().keys();
    return keys;
}

// Quilt dependency lists hold strings or {id, optional} objects.
QStringList quiltIds(const QJsonValue &value, bool skipOptional)
{
    QStringList ids;
    const QJsonArray list = value.isArray() ? value.toArray() : QJsonArray{value};
    for (const auto &item : list) {
        if (item.isString()) ids << item.toString().section('@', 0, 0).section(':', -1);
        else if (item.isObject() && !(skipOptional && item.toObject().value("optional").toBool()))
            ids << item.toObject().value("id").toString().section(':', -1);
    }
    ids.removeAll(QString());
    return ids;
}

void addNestedIds(Mod &mod, const QHash<QString, QByteArray> &nested)
{
    for (const auto &bytes : nested) {
        const auto files = Mods::readArchiveBytes(bytes, metadataNames);
        const auto fabric = QJsonDocument::fromJson(files.value("fabric.mod.json")).object();
        if (!fabric.isEmpty()) {
            mod.provides.insert(fabric.value("id").toString());
            for (const auto &alias : fabric.value("provides").toArray()) mod.provides.insert(alias.toString());
        }
        const auto quilt = QJsonDocument::fromJson(files.value("quilt.mod.json")).object().value("quilt_loader").toObject();
        if (!quilt.isEmpty()) { mod.provides.insert(quilt.value("id").toString()); for (const auto &id : quiltIds(quilt.value("provides"), false)) mod.provides.insert(id); }
        for (const auto *name : {"META-INF/mods.toml", "META-INF/neoforge.mods.toml"})
            for (const auto &block : tomlBlocks(QString::fromUtf8(files.value(name))))
                if (block.header == "mods") mod.provides.insert(block.values.value("modId"));
    }
}

// Reads the metadata section that applies to `loader`, so multi-loader jars are judged correctly.
Mod readMod(const QFileInfo &file, const QString &loader)
{
    Mod mod;
    mod.fileName = file.fileName();
    mod.enabled = !mod.fileName.endsWith(".disabled");
    mod.name = mod.fileName.section(".jar", 0, 0);
    const auto files = Mods::readArchiveFiles(file.absoluteFilePath(), metadataNames + QStringList{"META-INF/jarjar/metadata.json"});
    const auto fabric = QJsonDocument::fromJson(files.value("fabric.mod.json")).object();
    const auto quilt = QJsonDocument::fromJson(files.value("quilt.mod.json")).object().value("quilt_loader").toObject();
    const QString neoToml = QString::fromUtf8(files.value("META-INF/neoforge.mods.toml"));
    const QString forgeToml = QString::fromUtf8(files.value("META-INF/mods.toml"));
    if (!fabric.isEmpty()) mod.loaders << "Fabric";
    if (!quilt.isEmpty()) mod.loaders << "Quilt";
    if (!neoToml.isEmpty()) mod.loaders << "NeoForge";
    if (!forgeToml.isEmpty()) mod.loaders << "Forge";

    const bool useQuilt = !quilt.isEmpty() && (loader == "Quilt" || fabric.isEmpty());
    const bool useFabric = !useQuilt && !fabric.isEmpty() && (loader == "Fabric" || loader == "Quilt" || (neoToml.isEmpty() && forgeToml.isEmpty()));
    if (useQuilt) {
        mod.ids << quilt.value("id").toString();
        mod.name = quilt.value("metadata").toObject().value("name").toString(mod.ids.first());
        for (const auto &id : quiltIds(quilt.value("provides"), false)) mod.provides.insert(id);
        mod.depends = quiltIds(quilt.value("depends"), true);
        mod.breaks = quiltIds(quilt.value("breaks"), false);
        if (quilt.value("jars").isArray()) addNestedIds(mod, Mods::readArchiveFolder(file.absoluteFilePath(), "META-INF/jars/", 32 * 1024 * 1024));
    } else if (useFabric) {
        mod.ids << fabric.value("id").toString();
        mod.name = fabric.value("name").toString(mod.ids.first());
        for (const auto &alias : fabric.value("provides").toArray()) mod.provides.insert(alias.toString());
        mod.depends = jsonKeys(fabric.value("depends"));
        mod.breaks = jsonKeys(fabric.value("breaks"));
        mod.discouraged = jsonKeys(fabric.value("conflicts"));
        if (fabric.value("jars").isArray() && !fabric.value("jars").toArray().isEmpty())
            addNestedIds(mod, Mods::readArchiveFolder(file.absoluteFilePath(), "META-INF/jars/", 32 * 1024 * 1024));
    } else if (!neoToml.isEmpty() || !forgeToml.isEmpty()) {
        const QString toml = loader == "Forge" && !forgeToml.isEmpty() ? forgeToml : (!neoToml.isEmpty() ? neoToml : forgeToml);
        for (const auto &block : tomlBlocks(toml)) {
            if (block.header == "mods") {
                const QString id = block.values.value("modId");
                if (!id.isEmpty()) mod.ids << id;
                if (mod.ids.size() == 1) mod.name = block.values.value("displayName", id);
            } else if (block.header.startsWith("dependencies.")) {
                const QString id = block.values.value("modId");
                const QString type = block.values.value("type").toLower();
                const bool mandatory = block.values.value("mandatory") == "true";
                if (id.isEmpty()) continue;
                // NeoForge uses `type`; Forge uses `mandatory`. Client- or server-only entries are skipped.
                const QString side = block.values.value("side", "BOTH").toUpper();
                if (side != "BOTH" && side != "CLIENT") continue;
                if (type == "required" || (type.isEmpty() && mandatory)) mod.depends << id;
                else if (type == "incompatible") mod.breaks << id;
                else if (type == "discouraged") mod.discouraged << id;
            }
        }
        if (files.contains("META-INF/jarjar/metadata.json"))
            addNestedIds(mod, Mods::readArchiveFolder(file.absoluteFilePath(), "META-INF/jarjar/", 32 * 1024 * 1024));
    }
    mod.ids.removeAll(QString());
    for (const auto &id : mod.ids) mod.provides.insert(id);
    mod.provides.remove(QString());
    return mod;
}

bool versionAtLeast(const QString &version, int major, int minor, int patch)
{
    const auto parts = version.split('.');
    const int a = parts.value(0).toInt(), b = parts.value(1).toInt(), c = parts.value(2).toInt();
    if (a != major) return a > major;
    if (b != minor) return b > minor;
    return c >= patch;
}

bool runsOn(const Mod &mod, const QString &loader, const QString &minecraft)
{
    if (mod.loaders.isEmpty()) return true; // Libraries without metadata are left alone.
    if (mod.loaders.contains(loader)) return true;
    if (loader == "Quilt" && mod.loaders.contains("Fabric")) return true;
    // NeoForge still loaded Forge-format mods before Minecraft 1.20.5.
    if (loader == "NeoForge" && mod.loaders.contains("Forge") && !versionAtLeast(minecraft, 1, 20, 5)) return true;
    return false;
}

QVariantMap fix(const QString &label, const QString &action, const QVariant &value)
{
    return {{"label", label}, {"action", action}, {"value", value}};
}
}

QVariantList ModHealth::analyze(const QString &modsDir, const QString &loader, const QString &minecraft)
{
    QVector<Mod> mods;
    for (const auto &file : QDir(modsDir).entryInfoList({"*.jar", "*.jar.disabled"}, QDir::Files, QDir::Name))
        mods.append(readMod(file, loader));
    QVariantList issues;
    const auto enabledMods = [&] { QVector<const Mod *> out; for (const auto &mod : mods) if (mod.enabled) out << &mod; return out; }();
    if (loader == "Vanilla") {
        if (!enabledMods.isEmpty())
            issues.append(QVariantMap{{"severity", "warning"}, {"kind", "loader"}, {"title", "Vanilla does not load mods"},
                {"detail", QString::number(enabledMods.size()) + " jars in the mods folder are ignored. Change the loader in Minecraft & loader."}, {"files", QStringList()}, {"fixes", QVariantList()}});
        return issues;
    }
    QVector<const Mod *> active;
    for (const auto *mod : enabledMods) {
        if (runsOn(*mod, loader, minecraft)) { active << mod; continue; }
        issues.append(QVariantMap{{"severity", "warning"}, {"kind", "loader"}, {"title", mod->name + " is made for " + mod->loaders.join(" / ")},
            {"detail", loader + " will not load " + mod->fileName + "."}, {"files", QStringList{mod->fileName}},
            {"fixes", QVariantList{fix("Disable", "disable", QStringList{mod->fileName}), fix("Find a " + loader + " version", "browse", mod->name)}}});
    }
    // Two enabled jars with the same mod id.
    QMap<QString, QStringList> owners;
    for (const auto *mod : active) for (const auto &id : mod->ids) owners[id] << mod->fileName;
    for (auto it = owners.cbegin(); it != owners.cend(); ++it) {
        if (it.value().size() < 2) continue;
        QString name = it.key();
        for (const auto *mod : active) if (mod->ids.contains(it.key())) { name = mod->name; break; }
        const QStringList extra = it.value().mid(1);
        issues.append(QVariantMap{{"severity", "error"}, {"kind", "duplicate"}, {"title", "Two copies of " + name},
            {"detail", it.value().join(", ") + " provide the same mod. The game refuses to start with duplicates."}, {"files", it.value()},
            {"fixes", QVariantList{fix("Keep " + it.value().first(), "disable", extra), fix("Keep " + it.value().last(), "disable", it.value().mid(0, it.value().size() - 1))}}});
    }
    QSet<QString> available = builtIn;
    for (const auto *mod : active) available.unite(mod->provides);
    // Required dependencies, grouped by the missing id.
    QMap<QString, QStringList> missing;
    for (const auto *mod : active) for (const auto &id : mod->depends) if (!available.contains(id)) missing[id] << mod->name;
    for (auto it = missing.cbegin(); it != missing.cend(); ++it) {
        QVariantList fixes;
        for (const auto &mod : mods)
            if (!mod.enabled && mod.provides.contains(it.key()) && runsOn(mod, loader, minecraft)) { fixes << fix("Enable " + mod.name, "enable", QStringList{mod.fileName}); break; }
        fixes << fix("Search for " + it.key(), "browse", it.key());
        QStringList requiredBy = it.value(); requiredBy.removeDuplicates();
        issues.append(QVariantMap{{"severity", "error"}, {"kind", "missing"}, {"title", "Missing " + it.key()},
            {"detail", "Required by " + requiredBy.join(", ") + "."}, {"files", QStringList()}, {"fixes", fixes}});
    }
    // Declared incompatibilities (errors) and discouraged pairs (warnings).
    QSet<QString> reported;
    for (const auto *mod : active) {
        for (const auto &[list, severity] : {std::pair{&mod->breaks, QStringLiteral("error")}, std::pair{&mod->discouraged, QStringLiteral("warning")}}) {
            for (const auto &id : *list) {
                for (const auto *other : active) {
                    if (other == mod || !other->provides.contains(id)) continue;
                    const QString key = QStringList{mod->fileName, other->fileName}.join('|');
                    if (reported.contains(key) || reported.contains(QStringList{other->fileName, mod->fileName}.join('|'))) continue;
                    reported.insert(key);
                    issues.append(QVariantMap{{"severity", severity}, {"kind", "incompatible"},
                        {"title", mod->name + (severity == "error" ? " is incompatible with " : " may conflict with ") + other->name},
                        {"detail", mod->fileName + " declares " + other->fileName + " as " + (severity == "error" ? "incompatible." : "a known conflict.")},
                        {"files", QStringList{mod->fileName, other->fileName}},
                        {"fixes", QVariantList{fix("Disable " + other->name, "disable", QStringList{other->fileName}), fix("Disable " + mod->name, "disable", QStringList{mod->fileName})}}});
                }
            }
        }
    }
    std::stable_sort(issues.begin(), issues.end(), [](const QVariant &a, const QVariant &b) {
        return a.toMap().value("severity") == "error" && b.toMap().value("severity") != "error";
    });
    return issues;
}

int ModHealth::errors() const
{
    return std::count_if(m_issues.cbegin(), m_issues.cend(), [](const QVariant &it) { return it.toMap().value("severity") == "error"; });
}

int ModHealth::warnings() const
{
    return m_issues.size() - errors();
}

void ModHealth::check(const QString &instanceId)
{
    const auto info = m_model ? m_model->getById(instanceId) : QVariantMap();
    const quint64 generation = ++m_generation;
    m_id = instanceId;
    m_issues.clear();
    m_checking = !info.isEmpty();
    emit changed();
    if (info.isEmpty()) return;
    const QString mods = Prism::gameDir(m_model->instancePath(instanceId)) + "/mods";
    const QString loader = info.value("loader").toString(), minecraft = info.value("version").toString();
    auto *watcher = new QFutureWatcher<QVariantList>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher, generation] {
        watcher->deleteLater();
        if (generation != m_generation) return;
        m_issues = watcher->result();
        m_checking = false;
        emit changed();
    });
    watcher->setFuture(QtConcurrent::run([mods, loader, minecraft] { return analyze(mods, loader, minecraft); }));
}
