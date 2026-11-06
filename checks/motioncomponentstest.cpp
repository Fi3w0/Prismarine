#include <QtTest>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <memory>

namespace {
std::unique_ptr<QQuickWindow> fixture(QQmlEngine &engine)
{
    QQmlComponent component(&engine);
    component.setData(R"(
        import QtQuick
        import QtQuick.Controls
        Window {
            id: host
            width: 640; height: 480; visible: true
            property bool secondPage: false
            property bool backwards: false
            property bool motionEnabled: true
            property int activations: 0
            onMotionEnabledChanged: Colors.animations = motionEnabled
            Component.onCompleted: Colors.animations = motionEnabled
            MotionLoader {
                id: pages
                objectName: "pages"
                x: 32; y: 32; width: 400; height: 240
                backwards: host.backwards
                sourceComponent: host.secondPage ? second : first
            }
            Component { id: first; Button { text: "First"; onClicked: host.activations++ } }
            Component { id: second; Button { text: "Second"; onClicked: host.activations++ } }
            MotionDialog {
                objectName: "dialog"
                parent: host.contentItem
                x: 180; y: 120; width: 280; height: 180
                modal: true; focus: true
                title: "Motion check"
                standardButtons: Dialog.Ok | Dialog.Cancel
            }
        }
    )", QUrl("qrc:/motion/Fixture.qml"));
    if (!component.isReady()) { qWarning() << component.errors(); return {}; }
    return std::unique_ptr<QQuickWindow>(qobject_cast<QQuickWindow *>(component.create()));
}
}

class MotionComponentsTest : public QObject {
    Q_OBJECT
private slots:
    void pagesRemainInteractiveAndSettleAfterInterruptions()
    {
        QQmlEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        auto window = fixture(engine);
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window.get()));
        auto *pages = window->findChild<QQuickItem *>("pages");
        QVERIFY(pages);
        QTest::qWait(250);
        const auto restingX = pages->x();

        window->setProperty("secondPage", true);
        QVERIFY(pages->mapToScene(QPointF()).x() > restingX);
        auto *button = pages->property("item").value<QQuickItem *>();
        QVERIFY(button);
        button->forceActiveFocus();
        QTest::keyClick(window.get(), Qt::Key_Space);
        QCOMPARE(window->property("activations").toInt(), 1);
        QTRY_COMPARE(pages->opacity(), 1.0);
        QTRY_COMPARE(pages->mapToScene(QPointF()).x(), restingX);

        window->setProperty("backwards", true);
        window->setProperty("secondPage", false);
        QVERIFY(pages->mapToScene(QPointF()).x() < restingX);
        QTest::qWait(30);
        window->setProperty("motionEnabled", false);
        QCOMPARE(pages->opacity(), 1.0);
        QCOMPARE(pages->mapToScene(QPointF()).x(), restingX);

        window->setProperty("motionEnabled", true);
        window->setProperty("secondPage", true);
        QTest::qWait(30);
        window->hide();
        QCOMPARE(pages->opacity(), 1.0);
        QCOMPARE(pages->mapToScene(QPointF()).x(), restingX);
        window->show();
        QVERIFY(QTest::qWaitForWindowExposed(window.get()));

        for (int index = 0; index < 8; ++index) {
            window->setProperty("backwards", index % 2 == 0);
            window->setProperty("secondPage", index % 2 == 0);
            QTest::qWait(15);
        }
        QTRY_COMPARE(pages->opacity(), 1.0);
        QTRY_COMPARE(pages->mapToScene(QPointF()).x(), restingX);
        window->setProperty("motionEnabled", false);
        window->setProperty("secondPage", true);
        QCOMPARE(pages->opacity(), 1.0);
        QCOMPARE(pages->mapToScene(QPointF()).x(), restingX);
        QTest::qWait(250);
        QSignalSpy frames(window.get(), &QQuickWindow::frameSwapped);
        QTest::qWait(250);
        QVERIFY(frames.isEmpty());
        QVERIFY(warnings.isEmpty());
    }

    void dialogsRecoverFromInterruptedOpenClose()
    {
        QQmlEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        auto window = fixture(engine);
        QVERIFY(window);
        QVERIFY(QTest::qWaitForWindowExposed(window.get()));
        auto *dialog = window->findChild<QObject *>("dialog");
        QVERIFY(dialog);
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QTest::qWait(40);
        QVERIFY(QMetaObject::invokeMethod(dialog, "close"));
        QTest::qWait(20);
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        QCOMPARE(dialog->property("opacity").toReal(), 1.0);
        QCOMPARE(dialog->property("scale").toReal(), 1.0);
        QVERIFY(dialog->property("activeFocus").toBool());
        QTest::keyClick(window.get(), Qt::Key_Escape);
        QTRY_VERIFY(!dialog->property("visible").toBool());

        window->setProperty("motionEnabled", false);
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QVERIFY(dialog->property("opened").toBool());
        QCOMPARE(dialog->property("opacity").toReal(), 1.0);
        QCOMPARE(dialog->property("scale").toReal(), 1.0);
        QVERIFY(QMetaObject::invokeMethod(dialog, "close"));
        QVERIFY(!dialog->property("visible").toBool());
        window->setProperty("motionEnabled", true);
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QTest::qWait(30);
        window->setProperty("motionEnabled", false);
        // Qt owns an in-flight popup transition; it finishes, then new transitions snap.
        QTRY_COMPARE_WITH_TIMEOUT(dialog->property("opacity").toReal(), 1.0, 250);
        QTRY_COMPARE_WITH_TIMEOUT(dialog->property("scale").toReal(), 1.0, 250);
        QVERIFY(QMetaObject::invokeMethod(dialog, "close"));
        QTRY_VERIFY(!dialog->property("visible").toBool());

        window->setProperty("motionEnabled", true);
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QTest::qWait(30);
        window->hide();
        QTest::qWait(250);
        window->show();
        QVERIFY(QTest::qWaitForWindowExposed(window.get()));
        QVERIFY(QMetaObject::invokeMethod(dialog, "open"));
        QTRY_VERIFY(dialog->property("opened").toBool());
        QCOMPARE(dialog->property("opacity").toReal(), 1.0);
        QCOMPARE(dialog->property("scale").toReal(), 1.0);
        QVERIFY(QMetaObject::invokeMethod(dialog, "close"));
        QTRY_VERIFY(!dialog->property("visible").toBool());
        auto *pages = window->findChild<QQuickItem *>("pages");
        QVERIFY(pages);
        auto *button = pages->property("item").value<QQuickItem *>();
        QVERIFY(button);
        QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier,
                         button->mapToScene(QPointF(button->width() / 2, button->height() / 2)).toPoint());
        QCOMPARE(window->property("activations").toInt(), 1);
        QTest::qWait(250);
        QSignalSpy frames(window.get(), &QQuickWindow::frameSwapped);
        QTest::qWait(250);
        QVERIFY(frames.isEmpty());
        QVERIFY(warnings.isEmpty());
    }
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Basic");
    MotionComponentsTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "motioncomponentstest.moc"
