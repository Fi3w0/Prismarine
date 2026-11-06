#include <QImage>
#include <QBuffer>
#include <QTcpSocket>
#include <QTcpServer>
#include <QtTest>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <algorithm>
#include <cmath>
#include <memory>

class NavigationMotionTest : public QObject {
    Q_OBJECT
private slots:
    void indicatorOnlyAnimatesWhenUseful()
    {
        QQmlEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        QQmlComponent component(&engine);
        component.setData(R"(
            import QtQuick
            import QtQuick.Window
            Window {
                id: host
                width: 72; height: 875; visible: true
                property bool gameActive: false
                property string gameState: "exited"
                property bool motionEnabled: true
                property var externalGames: []
                property var session: ({ active: gameActive, state: gameState })
                property var games: ({ games: externalGames })
                property var social: null
                property var instances: ({ accounts: [] })
                property string logoFile: "shard-o.svg"
                property string page: "home"
                onMotionEnabledChanged: Colors.animations = motionEnabled
                Component.onCompleted: Colors.animations = motionEnabled
                NavigationRail { anchors.fill: parent; controller: host }
            }
        )", QUrl("qrc:/checks/Fixture.qml"));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));
        auto *window = qobject_cast<QQuickWindow *>(root.get());
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *navigation = window->findChild<QQuickItem *>("sessionNavButton");
        QVERIFY(navigation);
        QQuickItem *indicator = nullptr;
        for (auto *child : navigation->childItems())
            if (child->width() == 8 && child->height() == 8) indicator = child;
        QVERIFY(indicator);
        QSignalSpy frames(window, &QQuickWindow::frameSwapped);
        auto verifySettled = [&] {
            QTest::qWait(300); // Let finite hover/visibility transitions and image loads settle.
            frames.clear();
            QTest::qWait(250);
            return frames.isEmpty();
        };
        QVERIFY2(verifySettled(), "The idle navigation rail continuously renders frames");
        QVERIFY(!indicator->isVisible());

        window->setProperty("gameState", "running");
        window->setProperty("gameActive", true);
        QTRY_VERIFY(indicator->isVisible());
        QTRY_VERIFY(indicator->opacity() < 0.95);

        window->setProperty("motionEnabled", false);
        QTRY_COMPARE(indicator->opacity(), 1.0);
        QVERIFY(verifySettled());
        window->setProperty("motionEnabled", true);
        QTRY_VERIFY(indicator->opacity() < 0.95);

        window->hide();
        QTest::qWait(100);
        QCOMPARE(indicator->opacity(), 1.0);
        window->show();
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QTRY_VERIFY(indicator->opacity() < 0.95);

        window->setVisibility(QWindow::Minimized);
        QTRY_COMPARE(indicator->opacity(), 1.0);
        window->showNormal();
        QVERIFY(QTest::qWaitForWindowExposed(window));
        QTRY_VERIFY(indicator->opacity() < 0.95);

        window->setProperty("gameState", "exited");
        QTRY_VERIFY(!indicator->isVisible());
        QVERIFY(verifySettled());

        // Games discovered outside the followed session also activate the indicator.
        window->setProperty("externalGames", QVariantList{QVariantMap{{"state", "running"}}});
        QTRY_VERIFY(indicator->isVisible());
        QTRY_VERIFY(indicator->opacity() < 0.95);
        window->setProperty("externalGames", QVariantList{QVariantMap{{"state", "exited"}}});
        QTRY_VERIFY(!indicator->isVisible());
        QVERIFY(verifySettled());
        QVERIFY(warnings.isEmpty());
    }

    void railKeepsLabelsAtMinimumWindowHeight()
    {
        QQmlEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        QQmlComponent component(&engine);
        // Friends is visible, which is the tallest rail. 640 is Main.qml's minimum height.
        component.setData(R"(
            import QtQuick
            Window {
                id: host
                width: 76; height: 640; visible: true
                property var session: ({ active: false, state: "exited" })
                property var games: ({ games: [] })
                property var social: ({})
                property string logoFile: "shard-o.svg"
                property string page: "library"
                NavigationRail { anchors.fill: parent; controller: host }
            }
        )", QUrl("qrc:/checks/RailFixture.qml"));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));
        auto *window = qobject_cast<QQuickWindow *>(root.get());
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *session = window->findChild<QQuickItem *>("sessionNavButton");
        auto *settings = window->findChild<QQuickItem *>("settingsNavButton");
        QVERIFY(session);
        QVERIFY(settings);
        QVERIFY(session->property("labelShown").toBool());
        QTRY_COMPARE(session->height(), 58.0);
        const QPointF sessionBottom = session->mapToScene(QPointF(0, session->height()));
        const QPointF settingsTop = settings->mapToScene(QPointF(0, 0));
        QVERIFY2(sessionBottom.y() <= settingsTop.y(), "Rail buttons overlap at the minimum window height");
        QVERIFY(settingsTop.y() + settings->height() <= window->height());
        QVERIFY(settingsTop.x() >= 0 && settingsTop.x() + settings->width() <= window->width());
        QVERIFY(warnings.isEmpty());
    }

    void topBarSearchAndAccountWork()
    {
        QQmlEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        QQmlComponent component(&engine);
        // 884 is the content width beside the rail at Main.qml's minimum window width.
        component.setData(R"(
            import QtQuick
            import QtQuick.Layouts
            Window {
                id: host
                width: 884; height: 400; visible: true
                property int paletteOpens: 0
                property string page: "home"
                property string lastPage: ""
                property var instances: ({ accounts: [{ id: "a", name: "A very long Minecraft account name that must not take over", active: true }] })
                function openPalette() { ++paletteOpens }
                function navigate(target) { lastPage = target }
                ColumnLayout {
                    anchors.fill: parent
                    spacing: 0
                    TopBar { controller: host }
                    Item { Layout.fillHeight: true }
                }
            }
        )", QUrl("qrc:/checks/TopBarFixture.qml"));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));
        auto *window = qobject_cast<QQuickWindow *>(root.get());
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window));
        auto *bar = window->findChild<QQuickItem *>("topBar");
        auto *search = window->findChild<QQuickItem *>("topSearch");
        auto *account = window->findChild<QQuickItem *>("accountSwitcher");
        QVERIFY(bar);
        QVERIFY(search);
        QVERIFY(account);
        const QString shortcut = bar->property("searchShortcut").toString();
#ifdef Q_OS_MACOS
        QCOMPARE(shortcut, QStringLiteral("\u2318K"));
#else
        QCOMPARE(shortcut, QStringLiteral("Ctrl+K"));
#endif
        const QPoint searchCentre = search->mapToScene(QPointF(search->width() / 2, search->height() / 2)).toPoint();
        const QPointF accountLeft = account->mapToScene(QPointF(0, 0));
        QTRY_VERIFY(account->width() > 44);
        QVERIFY2(search->mapToScene(QPointF(search->width(), 0)).x() <= accountLeft.x(), "Search overlaps the account");
        QVERIFY(accountLeft.x() + account->width() <= window->width());

        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, searchCentre);
        QTRY_COMPARE(window->property("paletteOpens").toInt(), 1);

        const QPoint accountCentre = account->mapToScene(QPointF(account->width() / 2, account->height() / 2)).toPoint();
        QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier, accountCentre);
        QTRY_COMPARE(window->property("lastPage").toString(), QStringLiteral("accounts"));

        // The bar sits at the window's right edge, so the menu has to open inward.
        QTest::mouseClick(window, Qt::RightButton, Qt::NoModifier, accountCentre);
        auto *menu = window->findChild<QObject *>("accountSwitchMenu");
        QVERIFY(menu);
        QTRY_VERIFY(menu->property("visible").toBool());
        const double menuLeft = accountLeft.x() + menu->property("x").toDouble();
        QVERIFY(menuLeft >= 0);
        QVERIFY(menuLeft + menu->property("width").toDouble() <= window->width());
        QVERIFY(warnings.isEmpty());
    }

    void avatarFetchesEachTimeAndRetries()
    {
        // Answers with a failure, then a green picture, then a red one. Same cache header as GitHub.
        QTcpServer server;
        QVERIFY(server.listen(QHostAddress::LocalHost));
        int requests = 0;
        const auto picture = [](const QColor &colour) {
            QImage image(64, 64, QImage::Format_RGB32);
            image.fill(colour);
            QByteArray bytes;
            QBuffer buffer(&bytes);
            buffer.open(QIODevice::WriteOnly);
            image.save(&buffer, "PNG");
            return bytes;
        };
        connect(&server, &QTcpServer::newConnection, &server, [&] {
            while (auto *socket = server.nextPendingConnection()) {
                connect(socket, &QTcpSocket::disconnected, socket, &QObject::deleteLater);
                connect(socket, &QTcpSocket::readyRead, socket, [&, socket] {
                    socket->readAll();
                    const int number = ++requests;
                    const QByteArray body = number == 1 ? QByteArray() : picture(number == 2 ? Qt::green : Qt::red);
                    socket->write((number == 1 ? "HTTP/1.1 500 Failed\r\n" : "HTTP/1.1 200 OK\r\nContent-Type: image/png\r\nCache-Control: max-age=300\r\n")
                        + QByteArray("Connection: close\r\nContent-Length: ") + QByteArray::number(body.size()) + "\r\n\r\n" + body);
                    socket->disconnectFromHost();
                });
            }
        });
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(QString(R"(
            import QtQuick
            Window {
                width: 100; height: 100; visible: true
                property alias shown: page.active
                Loader {
                    id: page
                    sourceComponent: RoundAvatar { objectName: "avatar"; source: "%1"; fallback: "F"; retryDelays: [50] }
                }
            }
        )").arg(QStringLiteral("http:") + QStringLiteral("/") + QStringLiteral("/127.0.0.1:") + QString::number(server.serverPort()) + QStringLiteral("/face")).toUtf8(), QUrl("qrc:/checks/AvatarFixture.qml"));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> root(component.create());
        QVERIFY2(root, qPrintable(component.errorString()));
        auto *window = qobject_cast<QQuickWindow *>(root.get());
        QVERIFY(QTest::qWaitForWindowExposed(window));
        const auto centre = [&] { const QImage image = window->grabWindow(); return image.pixelColor(image.width() * 32 / 100, image.height() * 32 / 100); };
        const auto avatar = [&] { return window->findChild<QQuickItem *>("avatar"); };

        QTRY_COMPARE(requests, 2);
        QTRY_VERIFY(avatar()->property("ready").toBool());
        QTRY_COMPARE(centre(), QColor(Qt::green));

        // Leaving and coming back rebuilds the page: it must show, and pick up a changed picture.
        window->setProperty("shown", false);
        QTRY_VERIFY(!avatar());
        window->setProperty("shown", true);
        QTRY_VERIFY(avatar());
        QTRY_COMPARE(requests, 3);
        QTRY_VERIFY(avatar()->property("ready").toBool());
        QTRY_COMPARE(centre(), QColor(Qt::red));
    }

    void themeMeetsContrastMinimums()
    {
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.setData(R"(
            import QtQuick
            QtObject {
                property string theme: "deep"
                onThemeChanged: Colors.theme = theme
                property color userAccent: Colors.userAccent
                onUserAccentChanged: Colors.userAccent = userAccent
                readonly property color accent: Colors.accent
                readonly property color accentInk: Colors.accentInk
                readonly property var backgrounds: [Colors.rail, Colors.base, Colors.mantle, Colors.surface, Colors.surfaceHi, Colors.rowAlt, Colors.inset]
                readonly property color outline: Colors.outline
                readonly property color text: Colors.text
                readonly property color subtext: Colors.subtext
            }
        )", QUrl("qrc:/checks/ThemeFixture.qml"));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> tokens(component.create());
        QVERIFY2(tokens, qPrintable(component.errorString()));
        auto luminance = [](const QColor &color) {
            const auto channel = [](double value) { return value <= 0.03928 ? value / 12.92 : std::pow((value + 0.055) / 1.055, 2.4); };
            return 0.2126 * channel(color.redF()) + 0.7152 * channel(color.greenF()) + 0.0722 * channel(color.blueF());
        };
        auto contrast = [&](const QColor &a, const QColor &b) {
            const double x = luminance(a), y = luminance(b);
            return (std::max(x, y) + 0.05) / (std::min(x, y) + 0.05);
        };
        for (const char *theme : {"deep", "light"}) {
            tokens->setProperty("theme", QString::fromLatin1(theme));
            const auto backgrounds = tokens->property("backgrounds").toList();
            QCOMPARE(backgrounds.size(), 7);
            for (const QVariant &background : backgrounds) {
                const QColor colour = background.value<QColor>();
                const QByteArray where = QByteArray(theme) + " on " + colour.name().toLatin1();
                QVERIFY2(contrast(tokens->property("outline").value<QColor>(), colour) >= 3.0, where.constData());
                QVERIFY2(contrast(tokens->property("text").value<QColor>(), colour) >= 4.5, where.constData());
                QVERIFY2(contrast(tokens->property("subtext").value<QColor>(), colour) >= 4.5, where.constData());
                for (const char *preset : {"#46d1bb", "#7aa2ff", "#f0a35e", "#b892f2", "#d8c39a", "#f18ba8"}) {
                    tokens->setProperty("userAccent", QColor(preset));
                    const auto accent = tokens->property("accent").value<QColor>();
                    QVERIFY2(contrast(accent, colour) >= 4.5, (where + " accent " + preset).constData());
                    QVERIFY2(contrast(accent, tokens->property("accentInk").value<QColor>()) >= 4.5, preset);
                }
            }
        }
    }
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Basic");
    NavigationMotionTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "navigationmotiontest.moc"
