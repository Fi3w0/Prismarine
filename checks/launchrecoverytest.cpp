#include <QtTest>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <QTcpServer>
#include <QTcpSocket>
#include <QPointer>
#include <QUrlQuery>
#include <QJsonArray>
#include <QJsonDocument>
#include <QCryptographicHash>
#include "core/session/launchprogress.h"
#include "core/session/gamesession.h"
#include "core/session/crashanalyzer.h"
#include "core/install/contentinstaller.h"
#include <memory>

namespace {
QQuickItem *visual(QQuickItem *root, const QString &name)
{
    if (root->objectName() == name) return root;
    for (auto *child : root->childItems())
        if (auto *found = visual(child, name)) return found;
    return nullptr;
}
void write(const QString &path, const QByteArray &bytes)
{
    QDir().mkpath(QFileInfo(path).absolutePath());
    QFile file(path);
    QVERIFY(file.open(QIODevice::WriteOnly));
    QCOMPARE(file.write(bytes), bytes.size());
}
void library(const QString &root)
{
    write(root + "/instances/fixture/instance.cfg", "[General]\nname=Recovery fixture\nInstanceType=OneSix\n");
    write(root + "/instances/fixture/mmc-pack.json", R"({"components":[{"uid":"net.minecraft","version":"1.21.1"},{"uid":"net.fabricmc.fabric-loader","version":"0.16.0"}]})");
    QDir().mkpath(root + "/instances/fixture/.minecraft/mods");
}
const QByteArray missingApi = "Incompatible mods found!\n- Mod 'Example' (example) 1.0 requires any version of fabric-api, which is missing!\n\n";

// Loopback-only HTTP requests stay pending until the test supplies a response.
class LocalApi : public QObject {
public:
    QTcpServer server;
    QList<QPointer<QTcpSocket>> sockets;
    QList<QUrl> urls;
    LocalApi()
    {
        if (!server.listen(QHostAddress::LocalHost)) qFatal("Cannot listen on loopback");
        connect(&server, &QTcpServer::newConnection, this, [this] {
            while (auto *socket = server.nextPendingConnection()) {
                connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
                connect(socket, &QTcpSocket::readyRead, this, [this, socket] {
                    if (socket->property("complete").toBool()) return;
                    const auto buffer = socket->property("request").toByteArray() + socket->readAll();
                    socket->setProperty("request", buffer);
                    if (!buffer.contains("\r\n\r\n")) return;
                    socket->setProperty("complete", true);
                    sockets.append(socket);
                    urls.append(QUrl::fromEncoded(buffer.split('\n').first().split(' ').value(1)));
                });
            }
        });
    }
    QUrl base() const { return QUrl("http://127.0.0.1:" + QString::number(server.serverPort()) + "/v2"); }
    void respond(int index, const QByteArray &bytes, int status = 200)
    {
        QVERIFY(sockets.at(index));
        sockets[index]->write("HTTP/1.1 " + QByteArray::number(status) + " Response\r\nContent-Length: "
            + QByteArray::number(bytes.size()) + "\r\nConnection: close\r\n\r\n" + bytes);
        sockets[index]->disconnectFromHost();
    }
};
std::unique_ptr<QObject> window(QQmlEngine &engine, LaunchProgress &progress)
{
    QQmlComponent component(&engine);
    component.setData(R"(
        import QtQuick
        import QtQuick.Controls
        Window {
            id: host
            width: 960; height: 640; visible: true
            required property var launchProgress
            property var session: null
            property var desktop: null
            property string actionInstance: ""
            property string actionTarget: ""
            property bool acceptFix: true
            property QtObject instances: QtObject {
                function getById(id) { return {instanceId: id, name: "Recovery fixture", loader: "Fabric", version: "1.21.1"} }
                function copies() { return [] }
            }
            function coverFor(id, slot) { return "" }
            function screenshotFor(id, slot) { return false }
            function reviewLaunchFix(id, project) { actionInstance = id; actionTarget = project; return acceptFix }
            function openInstance(id, tab) { actionInstance = id; actionTarget = tab }
            function editSettings(id) { actionInstance = id; actionTarget = "settings" }
            function browseFor(id, query) { actionInstance = id; actionTarget = query }
            Component.onCompleted: Colors.animations = false
            LaunchOverlay { controller: host }
        }
    )", QUrl("qrc:/launch/Fixture.qml"));
    if (!component.isReady()) { qWarning() << component.errors(); return {}; }
    return std::unique_ptr<QObject>(component.createWithInitialProperties({{"launchProgress", QVariant::fromValue(&progress)}}));
}
}

class LaunchRecoveryTest : public QObject {
    Q_OBJECT
private slots:
    void engineEventsDriveProgress()
    {
        QTemporaryDir root;
        const QString events = root.path() + "/logs/prismarine-engine-events.jsonl";
        QDir().mkpath(root.path() + "/logs");
        const auto append = [&](const QByteArray &text) {
            QFile file(events);
            QVERIFY(file.open(QIODevice::Append));
            file.write(text);
        };
        append("{\"instance\":\"pack\",\"stage\":\"failed\",\"detail\":\"From an earlier launch\"}\n");
        LaunchProgress progress(root.path(), nullptr, 100000);
        progress.start("pack");
        progress.poll();
        QCOMPARE(progress.stage(), QStringLiteral("waiting"));

        append("{\"instance\":\"other\",\"stage\":\"failed\",\"detail\":\"Another instance\"}\n");
        append("{\"instance\":\"pack\",\"stage\":\"signin\",\"detail\":\"Refreshing your token\"}\n");
        progress.poll();
        QCOMPARE(progress.stage(), QStringLiteral("signin"));
        QCOMPARE(progress.detail(), QStringLiteral("Fetching Minecraft access"));
        const double signedIn = progress.progress();

        append("{\"instance\":\"pack\",\"stage\":\"files\",\"detail\":\"Downloading libraries\",\"fraction\":0.25}\n");
        progress.poll();
        const double quarter = progress.progress();
        QCOMPARE(progress.stage(), QStringLiteral("files"));
        QVERIFY(quarter > signedIn);
        append("{\"instance\":\"pack\",\"stage\":\"files\",\"detail\":\"Downloading libraries\",\"fraction\":0.75}\n");
        progress.poll();
        QVERIFY(progress.progress() > quarter);
        const double threeQuarters = progress.progress();

        // A line still being written waits for the rest of it.
        append("{\"instance\":\"pack\",\"stage\":\"java\",");
        progress.poll();
        QCOMPARE(progress.stage(), QStringLiteral("files"));
        append("\"detail\":\"Starting Java\"}\n");
        progress.poll();
        QCOMPARE(progress.stage(), QStringLiteral("java"));
        QVERIFY(progress.progress() > threeQuarters);

        append("{\"instance\":\"pack\",\"stage\":\"finished\"}\n");
        progress.poll();
        QCOMPARE(progress.stage(), QStringLiteral("java"));
        append("{\"instance\":\"pack\",\"stage\":\"failed\",\"detail\":\"Java could not start\"}\n");
        progress.poll();
        QCOMPARE(progress.stage(), QStringLiteral("failed"));
        QCOMPARE(progress.lastStage(), QStringLiteral("java"));
        QCOMPARE(progress.detail(), QStringLiteral("Java could not start"));
    }

    void retainsCompletedStepsAfterFailure()
    {
        QTemporaryDir root;
        const QString log = root.path() + "/logs/PrismLauncher-0.log";
        write(log, "");
        LaunchProgress progress(root.path(), nullptr, 100000);
        QQmlEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        auto host = window(engine, progress);
        QVERIFY(host);
        auto *overlay = host->findChild<QObject *>("launchOverlay"); QVERIFY(overlay);
        progress.start("fixture");
        progress.reach("files");
        QCOMPARE(overlay->property("current").toInt(), 1);
        progress.reach("game");
        QCOMPARE(overlay->property("current").toInt(), 3);
        progress.reach("failed", "Synthetic startup failure");
        QCOMPARE(overlay->property("current").toInt(), 3);
        for (int i = 0; i < 4; ++i) {
            auto *step = visual(overlay->property("contentItem").value<QQuickItem *>(), "launchStep_" + QString::number(i)); QVERIFY(step);
            QCOMPARE(step->property("done").toBool(), i < 3);
            QCOMPARE(step->property("active").toBool(), i == 3);
        }
        // All lines in one poll: QML receives only the final failed state.
        progress.start("fixture");
        write(log, "Debug: <> Instance \"fixture\" launching\nDebug: Checking game files\nDebug: -Djava.library.path=/fixture\nInfo: launch failed\n");
        progress.poll();
        QCOMPARE(progress.stage(), "failed");
        QCOMPARE(progress.lastStage(), "java");
        QCOMPARE(overlay->property("current").toInt(), 2);
        QCOMPARE(progress.progress(), 0.64);
        progress.start("fixture");
        QCOMPARE(overlay->property("current").toInt(), 0);
        progress.reach("files"); progress.abort();
        QCOMPARE(overlay->property("current").toInt(), 1);
        progress.start("fixture"); progress.reach("ready");
        QCOMPARE(overlay->property("current").toInt(), 4);
        QVERIFY(warnings.isEmpty());
    }
    void diagnosisBelongsToCurrentLaunch()
    {
        QTemporaryDir root, proc;
        library(root.path());
        const QString log = root.path() + "/instances/fixture/.minecraft/logs/latest.log";
        write(log, missingApi);
        QFile old(log); QVERIFY(old.open(QIODevice::ReadWrite));
        QVERIFY(old.setFileTime(QDateTime::currentDateTime().addSecs(-60), QFileDevice::FileModificationTime)); old.close();
        InstanceModel instances(nullptr, root.path());
        GameSession session(&instances, nullptr, proc.path());
        QVERIFY(session.start("fixture"));
        QVERIFY(session.launchDiagnosis().value("findings").toList().isEmpty());
        write(log, missingApi);
        auto findings = session.launchDiagnosis().value("findings").toList();
        QVERIFY(!findings.isEmpty());
        QCOMPARE(findings.first().toMap().value("project").toString(), "fabric-api");
        session.dismiss();
        QVERIFY(session.launchDiagnosis().isEmpty());
        const auto unknown = CrashAnalyzer::analyze("Incompatible mods found!\n- Mod 'A' (a) 1.0 requires any version of unrelated-mod, which is missing!\n");
        QVERIFY(!unknown.isEmpty());
        QVERIFY(!unknown.first().toMap().contains("project"));
        const auto named = CrashAnalyzer::analyze("Incompatible mods found!\n- Mod 'A' (a) 1.0 requires version 1 or later of mod 'Fabric API' (fabric-api), which is missing!\n");
        QCOMPARE(named.first().toMap().value("project").toString(), "fabric-api");
    }
    void recoveryActionsAndCompactLayout()
    {
        QTemporaryDir root;
        LaunchProgress progress(root.path(), nullptr, 100000);
        QQmlEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        auto host = window(engine, progress); QVERIFY(host);
        auto *view = qobject_cast<QQuickWindow *>(host.get()); QVERIFY(view);
        QVERIFY(QTest::qWaitForWindowExposed(view));
        auto *overlay = host->findChild<QObject *>("launchOverlay"); QVERIFY(overlay);
        const auto fail = [&] {
            progress.start("fixture"); progress.reach("game"); progress.reach("failed");
            const QVariantMap diagnosis{{"findings", CrashAnalyzer::analyze(QString::fromUtf8(missingApi))}};
            overlay->setProperty("diagnosis", diagnosis);
            QMetaObject::invokeMethod(overlay, "open");
        };
        fail(); QTest::qWait(50);
        QVERIFY(overlay->property("height").toReal() <= view->height() - 48);
        QVERIFY(overlay->property("y").toReal() >= 0);
        auto *install = host->findChild<QQuickItem *>("launchInstallFix"); QVERIFY(install);
        QVERIFY(install->isVisible());
        if (qEnvironmentVariableIsSet("PRISMARINE_CAPTURE_DIR")) {
            view->grabWindow().save(qEnvironmentVariable("PRISMARINE_CAPTURE_DIR") + "/failure-deep.png");
            QQmlComponent light(&engine); light.setData("import QtQml; QtObject { Component.onCompleted: Colors.theme = 'light' }", QUrl("qrc:/launch/Theme.qml"));
            std::unique_ptr<QObject> theme(light.create()); QTest::qWait(50);
            view->grabWindow().save(qEnvironmentVariable("PRISMARINE_CAPTURE_DIR") + "/failure-light.png");
        }
        host->setProperty("acceptFix", false);
        QVERIFY(QMetaObject::invokeMethod(install, "clicked"));
        QVERIFY(progress.active()); QVERIFY(overlay->property("visible").toBool());
        host->setProperty("acceptFix", true);
        QVERIFY(QMetaObject::invokeMethod(install, "clicked"));
        QCOMPARE(host->property("actionInstance").toString(), "fixture");
        QCOMPARE(host->property("actionTarget").toString(), "fabric-api");
        QVERIFY(!progress.active());
        fail();
        auto *logLink = host->findChild<QObject *>("launchViewLog"); QVERIFY(logLink);
        QVERIFY(QMetaObject::invokeMethod(logLink, "clicked"));
        QCOMPARE(host->property("actionTarget").toString(), "logs");
        fail();
        overlay->setProperty("diagnosis", QVariantMap{{"findings", CrashAnalyzer::analyze("Exception in thread \"main\" java.lang.OutOfMemoryError")}});
        auto *action = host->findChild<QObject *>("launchRecoveryAction"); QVERIFY(action);
        QVERIFY(QMetaObject::invokeMethod(action, "clicked"));
        QCOMPARE(host->property("actionTarget").toString(), "settings");
        fail();
        overlay->setProperty("diagnosis", QVariantMap{{"findings", CrashAnalyzer::analyze("Incompatible mods found!\n- Remove Mod 'Example' (example)\n")}});
        QVERIFY(QMetaObject::invokeMethod(action, "clicked"));
        QCOMPARE(host->property("actionTarget").toString(), "mods");
        fail();
        progress.start("fixture");
        QVERIFY(overlay->property("diagnosis").toMap().isEmpty());
        QVERIFY(warnings.isEmpty());
    }
    void preparesVerifiedFix_data()
    {
        QTest::addColumn<bool>("tamper");
        QTest::newRow("verified") << false;
        QTest::newRow("checksum-rejected") << true;
    }
    void preparesVerifiedFix()
    {
        QFETCH(bool, tamper);
        QTemporaryDir root;
        library(root.path());
        InstanceModel instances(nullptr, root.path());
        LocalApi api;
        ContentInstaller installer(&instances, nullptr, api.base());
        const QByteArray bytes = "synthetic mod fixture";
        const auto version = [&](const QString &id, const QString &type, const QString &game, const QString &date) {
            return QJsonObject{{"id", id}, {"project_id", "api-project"}, {"name", id}, {"version_type", type},
                {"game_versions", QJsonArray{game}}, {"loaders", QJsonArray{"fabric"}}, {"date_published", date},
                {"files", QJsonArray{QJsonObject{{"filename", id + ".jar"}, {"url", api.base().toString() + "/file.jar"},
                    {"hashes", QJsonObject{{"sha512", QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha512).toHex())}}}}}}};
        };
        installer.prepareProject("fixture", "fabric-api");
        QTRY_COMPARE(api.urls.size(), 1);
        QCOMPARE(api.urls[0].path(), "/v2/project/fabric-api/version");
        const QUrlQuery query(api.urls[0]);
        QCOMPARE(query.queryItemValue("game_versions", QUrl::FullyDecoded), "[\"1.21.1\"]");
        QCOMPARE(query.queryItemValue("loaders", QUrl::FullyDecoded), "[\"fabric\"]");
        api.respond(0, QJsonDocument(QJsonArray{version("beta", "beta", "1.21.1", "2026-01-01T00:00:00Z"),
            version("other-game", "release", "1.20.1", "2026-01-01T00:00:00Z"),
            version("older", "release", "1.21.1", "2024-01-01T00:00:00Z"),
            version("chosen", "release", "1.21.1", "2025-01-01T00:00:00Z")}).toJson());
        QTRY_COMPARE(installer.state(), "ready");
        QCOMPARE(installer.plan().size(), 1);
        QCOMPARE(installer.plan().first().toMap().value("filename").toString(), "chosen.jar");
        const QString installed = root.path() + "/instances/fixture/.minecraft/mods/chosen.jar";
        QVERIFY(!QFile::exists(installed)); // Resolving a fix never installs without confirmation.
        installer.install();
        QTRY_COMPARE(api.urls.size(), 2); api.respond(1, tamper ? "tampered" : bytes);
        QTRY_COMPARE(installer.state(), tamper ? "error" : "complete");
        QCOMPARE(QFile::exists(installed), !tamper);
    }
    void handlesUnavailableAndCancelledFixes()
    {
        QTemporaryDir root; library(root.path());
        InstanceModel instances(nullptr, root.path()); LocalApi api;
        ContentInstaller installer(&instances, nullptr, api.base());
        installer.prepareProject("fixture", "fabric-api");
        QTRY_COMPARE(api.urls.size(), 1); api.respond(0, "[]");
        QTRY_COMPARE(installer.state(), "error"); QVERIFY(installer.error().contains("No compatible release"));
        installer.prepareProject("fixture", "fabric-api");
        QTRY_COMPARE(api.urls.size(), 2); api.respond(1, "unavailable", 503);
        QTRY_COMPARE(installer.state(), "error");
        installer.prepareProject("fixture", "fabric-api");
        QTRY_COMPARE(api.urls.size(), 3); installer.cancel();
        QTest::qWait(20); QCOMPARE(installer.state(), "idle"); QVERIFY(installer.plan().isEmpty());
        installer.prepareProject("missing-instance", "fabric-api");
        QCOMPARE(installer.state(), "error"); QCOMPARE(api.urls.size(), 3);
    }
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Basic");
    LaunchRecoveryTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "launchrecoverytest.moc"
