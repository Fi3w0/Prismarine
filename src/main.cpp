#include <QDir>
#include <QFont>
#include <QFontDatabase>
#include <QIcon>
#include <QCommandLineParser>
#include <QRegularExpression>
#include <QGuiApplication>
#include <QQmlApplicationEngine>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTimer>
#include <QStandardPaths>
#include <QSysInfo>

#include "core/library/instancemodel.h"
#include "core/preferences/apppreferences.h"
#include "core/instance/instancedetails.h"
#include "core/catalog/modcatalog.h"
#include "core/settings/launchsettings.h"
#include "core/settings/javamanager.h"
#include "core/creation/instancecreator.h"
#include "core/accounts/accountmanager.h"
#include "core/install/contentinstaller.h"
#include "core/packs/packimporter.h"
#include "core/news/newsfeed.h"
#include "core/session/gamesession.h"
#include "core/install/modupdater.h"
#include "core/servers/serverlist.h"
#include "core/packs/packexporter.h"
#include "core/library/playtimehistory.h"
#include "core/social/socialmanager.h"
#include "core/storage/storagemanager.h"
#include "core/install/droppedfiles.h"
#include "core/mods/modhealth.h"
#include "core/library/altlaunch.h"
#include "core/settings/networksettings.h"
#include "core/session/launchprogress.h"
#include "core/settings/desktopintegration.h"
#include "core/session/gamemonitor.h"
#include "core/prism/launcherbridge.h"

int main(int argc, char *argv[])
{
    QGuiApplication app(argc, argv);
    app.setApplicationName("Prismarine");
    app.setApplicationVersion("0.4.0");
    app.setOrganizationName("Prismarine");
    app.setDesktopFileName("io.github.fi3w0.Prismarine");
    QQuickStyle::setStyle("Basic");

    QCommandLineParser parser;
    parser.setApplicationDescription("A native library and instance manager for Prism Launcher.");
    parser.addHelpOption();
    parser.addVersionOption();
    parser.addOption({"prism-data", "Read instances from this Prism data directory.", "directory"});
    parser.addOption({"screenshot", "Save the rendered window and quit.", "file"});
    parser.addOption({"window-size", "Set the initial window size, e.g. 1280x820.", "size"});
    parser.addOption({"preferences", "Use this Prismarine preferences file.", "file"});
    parser.addOption({"page", "Open home, library, settings, accounts, friends, browse, instance, or firstrun.", "page"});
    parser.addOption({"instance", "Instance to show on its detail page.", "id"});
    parser.addOption({"tab", "Instance detail tab to open.", "tab"});
    parser.addOption({"dialog", "Open a dialog for checking its layout, e.g. new-instance, import, rename, drop, group, storage.", "name"});
    parser.addOption({"section", "Settings section to open.", "name"});
    parser.process(app);
    app.setWindowIcon(QIcon(":/assets/logos/shard-o.svg"));
    for (const QString &name : QDir(":/assets/fonts").entryList({"*.ttf"})) {
        if (QFontDatabase::addApplicationFont(":/assets/fonts/" + name) < 0)
            qWarning() << "Could not load bundled font" << name;
    }
    QFont font(QStringList{"Outfit", "Noto Sans", "Sans Serif"});
    font.setPointSizeF(app.font().pointSizeF());
    app.setFont(font);

    AppPreferences preferences(parser.value("preferences"));
    // Known before the data folder is looked up: a portable Prism keeps its data beside it.
    Prism::setLauncherProgram(preferences.prismProgram());
    InstanceModel instances(nullptr, parser.value("prism-data"));
    InstanceDetails details(&instances);
    ModCatalog catalog;
    LaunchSettings launchSettings(&instances);
    JavaManager javaManager(&instances);
    InstanceCreator creator(&instances);
    AccountManager accountManager(&instances);
    SocialManager social(&accountManager);
    ContentInstaller installer(&instances);
    QObject::connect(&catalog, &ModCatalog::credentialsChanged, &installer, [&] { installer.setCurseForgeKey(catalog.curseForgeKey()); });
    installer.setCurseForgeKey(catalog.curseForgeKey());
    catalog.loadCredentials();
    PackImporter packImporter(&instances);
    NewsFeed news;
    GameSession session(&instances);
    ModUpdater updater(&instances);
    ServerList serverList(&instances);
    PackExporter packExporter(&instances);
    PlaytimeHistory playtime(&instances);
    StorageManager storage(&instances);
    DroppedFiles drops(&instances);
    ModHealth modHealth(&instances);
    AltLaunch altLaunch(&instances);
    NetworkSettings network(instances.dataDir());
    NetworkSettings::applyApplicationProxy(instances.dataDir());
    ServerList homeServers(&instances);
    LaunchProgress launchProgress(instances.dataDir());
    DesktopIntegration desktop;
    GameMonitor games(&instances, &session);
    QObject::connect(&app, &QCoreApplication::aboutToQuit, &preferences, &AppPreferences::sync);
    // Shown in Settings → About and copied by "Copy system info".
#if defined(__clang__)
    const QString compiler = QStringLiteral("Clang " __clang_version__);
#elif defined(__GNUC__)
    const QString compiler = QStringLiteral("GCC " __VERSION__);
#elif defined(_MSC_VER)
    const QString compiler = QStringLiteral("MSVC ") + QString::number(_MSC_VER);
#else
    const QString compiler = QStringLiteral("unknown");
#endif
    const QVariantMap appInfo{{"qtRuntime", QString::fromLatin1(qVersion())}, {"qtBuild", QStringLiteral(QT_VERSION_STR)},
        // Some os-release files quote PRETTY_NAME with single quotes, which Qt keeps.
        {"system", QSysInfo::prettyProductName().remove('\'')}, {"kernel", QSysInfo::kernelType() + " " + QSysInfo::kernelVersion()},
        {"architecture", QSysInfo::currentCpuArchitecture()}, {"compiler", compiler},
        {"appData", QStandardPaths::writableLocation(QStandardPaths::AppDataLocation)}};
    QQmlApplicationEngine engine;
    engine.setInitialProperties({{"instances", QVariant::fromValue(&instances)}, {"javaManager", QVariant::fromValue(&javaManager)},
        {"preferences", QVariant::fromValue(&preferences)}, {"details", QVariant::fromValue(&details)},
        {"catalog", QVariant::fromValue(&catalog)}, {"launchSettings", QVariant::fromValue(&launchSettings)},
        {"creator", QVariant::fromValue(&creator)}, {"accountManager", QVariant::fromValue(&accountManager)},
        {"installer", QVariant::fromValue(&installer)}, {"packImporter", QVariant::fromValue(&packImporter)},
        {"news", QVariant::fromValue(&news)}, {"session", QVariant::fromValue(&session)},
        {"updater", QVariant::fromValue(&updater)}, {"serverList", QVariant::fromValue(&serverList)},
        {"packExporter", QVariant::fromValue(&packExporter)}, {"playtime", QVariant::fromValue(&playtime)}, {"social", QVariant::fromValue(&social)},
        {"storage", QVariant::fromValue(&storage)}, {"drops", QVariant::fromValue(&drops)},
        {"modHealth", QVariant::fromValue(&modHealth)}, {"altLaunch", QVariant::fromValue(&altLaunch)},
        {"network", QVariant::fromValue(&network)}, {"homeServers", QVariant::fromValue(&homeServers)}, {"appInfo", appInfo},
        {"launchProgress", QVariant::fromValue(&launchProgress)}, {"desktop", QVariant::fromValue(&desktop)},
        {"games", QVariant::fromValue(&games)}});
    QObject::connect(&engine, &QQmlApplicationEngine::objectCreationFailed, &app,
                     [] { QCoreApplication::exit(1); }, Qt::QueuedConnection);
    engine.loadFromModule("Prismarine", "Main");
    auto *window = qobject_cast<QQuickWindow *>(engine.rootObjects().value(0));
    if (!window)
        return 1;
    if (parser.isSet("window-size")) {
        const auto match = QRegularExpression("^(\\d+)x(\\d+)$").match(parser.value("window-size"));
        if (!match.hasMatch() || match.captured(1).toInt() < 960 || match.captured(2).toInt() < 640) {
            qCritical() << "Window size must be WIDTHxHEIGHT, at least 960x640.";
            return 1;
        }
        window->resize(match.captured(1).toInt(), match.captured(2).toInt());
    }

    if (parser.isSet("page")) {
        const QString page = parser.value("page");
        if (!QStringList{"home", "library", "settings", "accounts", "friends", "browse", "instance", "session", "firstrun"}.contains(page)) {
            qCritical() << "Unknown page" << page;
            return 1;
        }
        // An explicit page skips the welcome; "firstrun" shows it without recording a choice.
        window->setProperty("showFirstRun", page == "firstrun");
        if (page == "instance") {
            const QString id = parser.isSet("instance") ? parser.value("instance") : instances.get(0).value("instanceId").toString();
            if (instances.getById(id).isEmpty()) { qCritical() << "Unknown instance" << id; return 1; }
            const QString tab = parser.isSet("tab") ? parser.value("tab") : "overview";
            if (!QStringList{"overview", "mods", "resourcepacks", "shaders", "worlds", "servers", "screenshots", "logs"}.contains(tab)) {
                qCritical() << "Unknown instance tab" << tab; return 1;
            }
            window->setProperty("instanceTab", tab);
            details.load(id);
        }
        if (page == "session") {
            // Follows an instance's current log without launching it, for checking the page.
            const QString id = parser.isSet("instance") ? parser.value("instance") : instances.get(0).value("instanceId").toString();
            if (!session.start(id)) { qCritical() << "Unknown instance" << id; return 1; }
            session.poll();
            if (parser.isSet("tab")) {
                if (parser.value("tab") != "all") { qCritical() << "Unknown session tab" << parser.value("tab"); return 1; }
                window->setProperty("sessionTab", "all");
            }
        }
        if (page != "firstrun")
            window->setProperty("page", page);
    }

    if (parser.isSet("section")) window->setProperty("settingsSection", parser.value("section"));
    if (parser.isSet("dialog")) window->setProperty("debugDialog", parser.value("dialog"));

    // --screenshot <file.png>: save the window once it has rendered, then quit.
    if (parser.isSet("screenshot")) {
        const QString file = parser.value("screenshot");
        QTimer::singleShot(1500, &app, [window, file] {
            if (!window->grabWindow().save(file)) {
                qCritical() << "Could not save screenshot to" << file;
                QCoreApplication::exit(1);
                return;
            }
            QCoreApplication::exit(0);
        });
    }

    return app.exec();
}
