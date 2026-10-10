#include "launchsettings.h"
#include "../prism/configreader.h"
#include "../prism/configwriter.h"
#include <QFileInfo>
#include <QFile>

LaunchSettings::LaunchSettings(InstanceModel *model, QObject *parent) : QObject(parent), m_model(model) {}
void LaunchSettings::load(const QString &id)
{
    if (!id.isEmpty() && m_model->getById(id).isEmpty()) {
        m_id = id; m_values.clear(); m_baseline.clear(); emit changed(); emit errorOccurred("This instance is no longer available."); return;
    }
    m_id = id;
    QFile original(id.isEmpty() ? m_model->dataDir() + "/prismlauncher.cfg" : m_model->instancePath(id) + "/instance.cfg");
    m_baseline = original.open(QIODevice::ReadOnly) ? original.readAll() : QByteArray();
    const auto global = Prism::readConfig(m_model->dataDir() + "/prismlauncher.cfg");
    const auto local = id.isEmpty() ? global : Prism::readConfig(m_model->instancePath(id) + "/instance.cfg");
    const bool automaticJava = global.value("AutomaticJavaSwitch", global.value("JavaPath").isEmpty() ? "true" : "false") == "true";
    const auto inherited = [&](const QString &key, const QString &flag, const QString &fallback) {
        return id.isEmpty() || local.value(flag).compare("true", Qt::CaseInsensitive) == 0
            ? local.value(key, fallback) : global.value(key, fallback);
    };
    m_values = {{"name", m_model->getById(id).value("name")},
        {"memoryOverride", id.isEmpty() || local.value("OverrideMemory") == "true"},
        {"minMemory", inherited("MinMemAlloc", "OverrideMemory", "512").toInt()},
        {"maxMemory", inherited("MaxMemAlloc", "OverrideMemory", "4096").toInt()},
        {"javaOverride", id.isEmpty() ? !automaticJava && !global.value("JavaPath").isEmpty() : local.value("OverrideJavaLocation") == "true"},
        {"javaPath", inherited("JavaPath", "OverrideJavaLocation", "")},
        {"jvmOverride", id.isEmpty() || local.value("OverrideJavaArgs") == "true"},
        {"windowOverride", id.isEmpty() || local.value("OverrideWindow") == "true"},
        {"performanceOverride", id.isEmpty() || local.value("OverridePerformance") == "true"},
        {"jvmArgs", inherited("JvmArgs", "OverrideJavaArgs", "")},
        {"width", inherited("MinecraftWinWidth", "OverrideWindow", "854").toInt()},
        {"height", inherited("MinecraftWinHeight", "OverrideWindow", "480").toInt()},
        {"maximized", inherited("LaunchMaximized", "OverrideWindow", "false") == "true"},
        {"joinServer", local.value("JoinServerOnLaunch") == "true"},
        {"server", local.value("JoinServerOnLaunchAddress")},
        {"accountId", local.value("UseAccountForInstance") == "true" ? local.value("InstanceAccountId") : ""},
        {"gameMode", inherited("EnableFeralGamemode", "OverridePerformance", "false") == "true"},
        {"mangoHud", inherited("EnableMangoHud", "OverridePerformance", "false") == "true"}};
    m_values.insert("commandsOverride", id.isEmpty() || local.value("OverrideCommands", local.value("OverrideLaunchCmd")) == "true");
    for (const auto &key : {"PreLoadCommand", "PreLaunchCommand", "PostExitCommand", "WrapperCommand"})
        m_values.insert(key, m_values.value("commandsOverride").toBool() ? local.value(key) : global.value(key));
    m_values.insert("autoJava", automaticJava);
    m_values.insert("downloadJava", global.value("AutomaticJavaDownload", global.value("JavaPath").isEmpty() ? "true" : "false") == "true");
    emit changed();
}
bool LaunchSettings::save(const QVariantMap &v)
{
    if (!m_id.isEmpty() && m_model->getById(m_id).isEmpty()) { emit errorOccurred("This instance is no longer available."); return false; }
    const QString path = m_id.isEmpty() ? m_model->dataDir() + "/prismlauncher.cfg" : m_model->instancePath(m_id) + "/instance.cfg";
    QFile current(path);
    if (!current.open(QIODevice::ReadOnly) || current.readAll() != m_baseline) { emit errorOccurred("Settings changed while this form was open. Reopen it before saving."); return false; }
    const int min = v.value("minMemory").toInt(), max = v.value("maxMemory").toInt();
    if (min < 256 || max < min || max > 262144 || v.value("width").toInt() < 320 || v.value("height").toInt() < 240 || v.value("width").toInt() > 16384 || v.value("height").toInt() > 16384) {
        emit errorOccurred("Check the memory range and window size."); return false;
    }
    if (v.value("javaOverride").toBool() && !QFileInfo(v.value("javaPath").toString()).isExecutable()) {
        emit errorOccurred("Choose an executable Java binary, or turn off the custom Java path."); return false;
    }
    if (!m_id.isEmpty() && v.value("name").toString().trimmed().isEmpty()) { emit errorOccurred("Give this instance a name."); return false; }
    QVariantMap updates{{"MinMemAlloc", min}, {"MaxMemAlloc", max}, {"JavaPath", v.value("javaOverride").toBool() ? v.value("javaPath") : QVariant("")},
        {"JvmArgs", v.value("jvmArgs")}, {"MinecraftWinWidth", v.value("width")}, {"MinecraftWinHeight", v.value("height")},
        {"LaunchMaximized", v.value("maximized")}, {"EnableFeralGamemode", v.value("gameMode")}, {"EnableMangoHud", v.value("mangoHud")}};
    if (!m_id.isEmpty()) {
        updates.insert("name", v.value("name"));
        updates.insert("OverrideMemory", v.value("memoryOverride"));
        updates.insert("OverrideJavaLocation", v.value("javaOverride"));
        if (v.value("javaOverride").toBool()) updates.insert("AutomaticJava", false);
        updates.insert("OverrideJavaArgs", v.value("jvmOverride"));
        updates.insert("OverrideWindow", v.value("windowOverride"));
        updates.insert("OverridePerformance", v.value("performanceOverride"));
        updates.insert("JoinServerOnLaunch", v.value("joinServer"));
        updates.insert("JoinServerOnLaunchAddress", v.value("server"));
        updates.insert("UseAccountForInstance", !v.value("accountId").toString().isEmpty());
        updates.insert("InstanceAccountId", v.value("accountId"));
    }
    for (const auto &key : {"PreLoadCommand", "PreLaunchCommand", "PostExitCommand", "WrapperCommand"})
        updates.insert(key, v.value(key));
    if (m_id.isEmpty()) {
        updates.insert("AutomaticJavaSwitch", v.value("autoJava"));
        updates.insert("AutomaticJavaDownload", v.value("downloadJava"));
    } else updates.insert("OverrideCommands", v.value("commandsOverride"));
    QString error;
    if (!Prism::writeConfig(path, updates, &error)) { emit errorOccurred(error); return false; }
    m_model->reload(); load(m_id); return true;
}
