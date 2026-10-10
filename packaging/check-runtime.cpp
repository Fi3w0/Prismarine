// CI checks the actual packaged Qt runtime and Windows file replacement semantics.
// This helper is never installed or included in a release.
#include <QCoreApplication>
#include <QDebug>
#include <QElapsedTimer>
#include <QFile>
#include <QFileInfo>
#include <QTemporaryDir>
#include <QThread>
#include <QUrl>
#include "core/accounts/accountmanager.h"
#include "core/library/instancemodel.h"
#include "core/preferences/apppreferences.h"
#include "core/prism/configreader.h"
#include "core/prism/launcherbridge.h"
#include "core/settings/launchsettings.h"

static bool write(const QString &path, const QByteArray &bytes)
{
    QFile file(path);
    return file.open(QIODevice::WriteOnly) && file.write(bytes) == bytes.size();
}

int main(int argc, char **argv)
{
    QCoreApplication app(argc, argv);
    // Stand in for an older Prism that accepts normal startup but not --show-window.
    if (argc > 1) {
        const QStringList args = app.arguments().mid(1);
        return args.size() == 2 && args.first() == "--dir"
            && write(qEnvironmentVariable("PRISMARINE_PACKAGE_CHILD_LOG"), args.join('\n').toUtf8()) ? 0 : 1;
    }
    const auto fail = [](const QString &error) { qCritical().noquote() << error; return 1; };
    QTemporaryDir root;
    if (!root.isValid()) return fail("Cannot create disposable settings directory");
    const QString config = root.path() + "/prismlauncher.cfg";
    if (!write(config, "[General]\nMinMemAlloc=512\nMaxMemAlloc=4096\nCustom=preserved\n")) return fail("Cannot create fixture");
    InstanceModel model(nullptr, root.path());
    LaunchSettings settings(&model);
    settings.load({});
    auto values = settings.values();
    values.insert("maxMemory", 8192);
    if (!settings.save(values)) return fail("Settings replacement failed");
    const auto saved = Prism::readConfig(config);
    if (saved.value("MaxMemAlloc") != "8192" || saved.value("Custom") != "preserved") return fail("Settings did not persist");
    if (!write(root.path() + "/accounts.json", R"({"accounts":[{"active":true,"profile":{"id":"a","name":"Alpha"}},{"active":false,"profile":{"id":"b","name":"Beta"}}]})")) return fail("Cannot create account fixture");
    AccountManager accounts(&model);
    if (!accounts.setDefault("b") || !accounts.remove("a")) return fail("Account file replacement failed");
    const QString preferences = root.path() + "/preferences.ini";
    const QString program = root.path() + "/Folder with spaces/Prism Launcher.exe";
    {
        AppPreferences prefs(preferences);
        prefs.setPrismProgramFromUrl(QUrl::fromLocalFile(program));
        prefs.setTheme("light");
        prefs.sync();
    }
    AppPreferences restored(preferences);
    if (restored.prismProgram() != program || restored.theme() != "light") return fail("Preferences or file-picker path did not persist");
    const QString log = root.path() + "/prism-arguments";
    qputenv("PRISMARINE_PACKAGE_CHILD_LOG", log.toUtf8());
    Prism::setLauncherProgram(QUrl::fromLocalFile(app.applicationFilePath()).toString());
    if (!model.openPrism()) return fail("Open Prism failed to start");
    QElapsedTimer timer;
    timer.start();
    while (QFileInfo(log).size() == 0 && timer.elapsed() < 5000) {
        app.processEvents();
        QThread::msleep(10);
    }
    QFile arguments(log);
    if (!arguments.open(QIODevice::ReadOnly) || arguments.readAll() != QString("--dir\n" + root.path()).toUtf8())
        return fail("Open Prism used unsupported startup arguments");
    qInfo("Packaged settings, accounts, preferences and Prism startup checks passed");
    return 0;
}
