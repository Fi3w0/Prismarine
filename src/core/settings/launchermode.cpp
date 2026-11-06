#include "launchermode.h"
#include "../prism/launcherbridge.h"
#include <QCoreApplication>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>

namespace {
struct Feature { const char *key, *title, *detail; };
const Feature features[] = {
    {"launchEvents", QT_TRANSLATE_NOOP("LauncherMode", "Accurate launch progress"), QT_TRANSLATE_NOOP("LauncherMode", "Real stages and failure reasons instead of reading Prism's log.")},
    {"nativeSignIn", QT_TRANSLATE_NOOP("LauncherMode", "Sign in inside Prismarine"), QT_TRANSLATE_NOOP("LauncherMode", "Add and refresh Microsoft accounts without a Prism window.")},
    {"quietAlways", QT_TRANSLATE_NOOP("LauncherMode", "Quiet launching everywhere"), QT_TRANSLATE_NOOP("LauncherMode", "No Prism windows, including on Flatpak and mismatched Qt versions.")},
    {"instantLaunch", QT_TRANSLATE_NOOP("LauncherMode", "Instant launches"), QT_TRANSLATE_NOOP("LauncherMode", "The engine is already running when you press Play.")},
    {"managedVersions", QT_TRANSLATE_NOOP("LauncherMode", "Install versions without launching"), QT_TRANSLATE_NOOP("LauncherMode", "Prepare Minecraft and loaders ahead of time.")},
};
QStringList engineCapabilities(const QString &program, bool *valid)
{
    *valid = false;
    if (!QFileInfo(program).isExecutable()) return {};
    QProcess process;
    process.start(program, {QStringLiteral("--engine-info")});
    if (!process.waitForFinished(2000)) { process.kill(); process.waitForFinished(500); return {}; }
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) return {};
    const QJsonObject info = QJsonDocument::fromJson(process.readAllStandardOutput()).object();
    if (info.value("protocol").toInt() != LauncherMode::EngineProtocol) return {};
    *valid = true;
    QStringList result;
    for (const auto &value : info.value("capabilities").toArray()) result.append(value.toString());
    return result;
}
}

LauncherMode::LauncherMode(const QString &engineDir, const QString &interfaceMode, QObject *parent)
    : QObject(parent), m_engineDir(!engineDir.isEmpty() ? engineDir : qEnvironmentVariableIsSet("PRISMARINE_ENGINE_DIR") ? qEnvironmentVariable("PRISMARINE_ENGINE_DIR") : QCoreApplication::applicationDirPath()),
      m_interfaceMode(validInterface(interfaceMode) ? interfaceMode : QStringLiteral("desktop"))
{
    refresh();
}

bool LauncherMode::validInterface(const QString &value)
{
    return value == QLatin1String("desktop") || value == QLatin1String("handheld");
}

void LauncherMode::setInterfaceMode(const QString &value)
{
    if (!validInterface(value) || value == m_interfaceMode) return;
    m_interfaceMode = value;
    emit interfaceModeChanged();
}

QVariantList LauncherMode::fullFeatures() const
{
    QVariantList result;
    for (const Feature &feature : features)
        result.append(QVariantMap{{"key", feature.key}, {"title", tr(feature.title)}, {"detail", tr(feature.detail)}, {"available", supports(feature.key)}});
    return result;
}

void LauncherMode::refresh()
{
#ifdef Q_OS_WIN
    const QString engine = m_engineDir + QStringLiteral("/prismarine-engine.exe");
#else
    const QString engine = m_engineDir + QStringLiteral("/prismarine-engine");
#endif
    bool valid = false;
    m_capabilities = engineCapabilities(engine, &valid);
    Prism::setEngineProgram(valid ? engine : QString());
    // A Prism program the user chose takes priority, and that means Stable mode.
    m_engineValid = valid && Prism::launcherProgram() == engine;
    if (!m_engineValid) m_capabilities.clear();
    Prism::setEngineProgram(m_engineValid ? engine : QString());
    if (m_engineValid) {
        Prism::setEngineProgram({});
        m_prismProgram = Prism::launcherProgram();
        Prism::setEngineProgram(engine);
    } else {
        m_prismProgram = Prism::launcherProgram();
    }
    emit changed();
}
