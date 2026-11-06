#include "core/preferences/apppreferences.h"
#include "core/settings/launchermode.h"
#include "core/prism/launcherbridge.h"
#include <QFile>
#include <QScopeGuard>
#include <QTemporaryDir>
#include <QtTest>

class LauncherModeTest : public QObject {
    Q_OBJECT
    static bool writeEngine(const QString &dir, const QByteArray &script)
    {
        QFile file(dir + "/prismarine-engine");
        if (!file.open(QIODevice::WriteOnly) || file.write(script) != script.size()) return false;
        file.close();
        return file.setPermissions(file.permissions() | QFile::ExeOwner);
    }
private slots:
    void withoutEngineEverythingIsStable()
    {
        QTemporaryDir dir;
        LauncherMode mode(dir.path());
        QCOMPARE(mode.mode(), QStringLiteral("stable"));
        QVERIFY(!mode.fullAvailable());
        QVERIFY(!mode.fullFeatures().isEmpty());
        for (const QVariant &feature : mode.fullFeatures())
            QVERIFY(!feature.toMap().value("available").toBool());
    }
    void validEngineReportsItsCapabilities()
    {
#ifdef Q_OS_WIN
        QSKIP("The fixture engine is a shell script.");
#endif
        QTemporaryDir dir;
        QVERIFY(writeEngine(dir.path(), "#!/bin/sh\n[ \"$1\" = --engine-info ] || exit 3\necho '{\"protocol\":1,\"capabilities\":[\"launchEvents\"]}'\n"));
        LauncherMode mode(dir.path());
        QCOMPARE(mode.mode(), QStringLiteral("full"));
        QVERIFY(mode.supports("launchEvents"));
        QVERIFY(!mode.supports("nativeSignIn"));
    }
    void launchesGoThroughTheEngineAndReportEvents()
    {
#ifdef Q_OS_WIN
        QSKIP("The fixture engine is a shell script.");
#endif
        const auto restore = qScopeGuard([] { Prism::setLauncherProgram({}); Prism::setEngineProgram({}); });
        Prism::setLauncherProgram({});
        QTemporaryDir dir, data;
        const QString argumentsFile = dir.path() + "/arguments";
        QVERIFY(writeEngine(dir.path(), "#!/bin/sh\nif [ \"$1\" = --engine-info ]; then echo '{\"protocol\":1,\"capabilities\":[\"launchEvents\"]}'; exit 0; fi\nprintf '%s\\n' \"$@\" > '" + argumentsFile.toUtf8() + "'\n"));
        LauncherMode mode(dir.path());
        QVERIFY(mode.fullAvailable());
        QCOMPARE(Prism::launcherProgram(), dir.path() + "/prismarine-engine");

        QString error;
        QVERIFY2(Prism::startLauncher(data.path(), {"--launch", "pack"}, &error), qPrintable(error));
        QTRY_VERIFY(QFileInfo::exists(argumentsFile) && QFileInfo(argumentsFile).size() > 0);
        QFile file(argumentsFile);
        QVERIFY(file.open(QIODevice::ReadOnly));
        const QStringList arguments = QString::fromUtf8(file.readAll()).split('\n', Qt::SkipEmptyParts);
        QCOMPARE(arguments, QStringList({"--dir", data.path(), "--engine-events", Prism::engineEventsPath(data.path()), "--launch", "pack"}));

        // A program the user chose wins, which means Stable mode.
        QTemporaryDir chosen;
        QFile custom(chosen.path() + "/my-prism");
        QVERIFY(custom.open(QIODevice::WriteOnly));
        custom.write("#!/bin/sh\n");
        custom.close();
        QVERIFY(custom.setPermissions(custom.permissions() | QFile::ExeOwner));
        Prism::setLauncherProgram(custom.fileName());
        mode.refresh();
        QCOMPARE(mode.mode(), QStringLiteral("stable"));
        QVERIFY(!mode.supports("launchEvents"));
        QCOMPARE(Prism::launcherProgram(), custom.fileName());

        // Without an engine nothing keeps pointing at it.
        Prism::setLauncherProgram({});
        QFile::remove(dir.path() + "/prismarine-engine");
        mode.refresh();
        QVERIFY(Prism::engineProgram().isEmpty());
    }
    void untrustworthyEnginesStayStable_data()
    {
        QTest::addColumn<QByteArray>("script");
        QTest::newRow("fails") << QByteArray("#!/bin/sh\nexit 1\n");
        QTest::newRow("garbage") << QByteArray("#!/bin/sh\necho not json\n");
        QTest::newRow("other protocol") << QByteArray("#!/bin/sh\necho '{\"protocol\":99,\"capabilities\":[\"launchEvents\"]}'\n");
        QTest::newRow("hangs") << QByteArray("#!/bin/sh\nexec sleep 30\n");
    }
    void untrustworthyEnginesStayStable()
    {
#ifdef Q_OS_WIN
        QSKIP("The fixture engine is a shell script.");
#endif
        QFETCH(QByteArray, script);
        QTemporaryDir dir;
        QVERIFY(writeEngine(dir.path(), script));
        LauncherMode mode(dir.path());
        QCOMPARE(mode.mode(), QStringLiteral("stable"));
        QVERIFY(!mode.supports("launchEvents"));
    }
    void interfaceAndFeaturePreferencesAreValidated()
    {
        QVERIFY(LauncherMode::validInterface("desktop"));
        QVERIFY(LauncherMode::validInterface("handheld"));
        QVERIFY(!LauncherMode::validInterface("console"));
        QCOMPARE(LauncherMode({}, "console").interfaceMode(), QStringLiteral("desktop"));
        QTemporaryDir dir;
        AppPreferences preferences(dir.path() + "/prefs.ini");
        QVERIFY(!preferences.friendsEnabled());
        QVERIFY(!preferences.hasFriendsChoice());
        QVERIFY(preferences.prismShortcuts());
        QCOMPARE(preferences.startInterface(), QStringLiteral("desktop"));
        preferences.setStartInterface("console");
        QCOMPARE(preferences.startInterface(), QStringLiteral("desktop"));
        preferences.setStartInterface("handheld");
        preferences.setFriendsEnabled(false);
        preferences.setPrismShortcuts(false);
        AppPreferences reloaded(dir.path() + "/prefs.ini");
        QCOMPARE(reloaded.startInterface(), QStringLiteral("handheld"));
        QVERIFY(!reloaded.friendsEnabled());
        QVERIFY(!reloaded.prismShortcuts());
    }
};

QTEST_GUILESS_MAIN(LauncherModeTest)
#include "launchermodetest.moc"
