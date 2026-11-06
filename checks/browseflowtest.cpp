#include <QtTest>
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QJSValue>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <memory>

namespace {
QQuickItem *findItem(QQuickItem *root, const QString &name)
{
    if (root->objectName() == name) return root;
    for (auto *child : root->childItems()) if (auto *found = findItem(child, name)) return found;
    return nullptr;
}
void click(QQuickWindow *window, QQuickItem *item)
{
    QTest::mouseClick(window, Qt::LeftButton, Qt::NoModifier,
                     item->mapToScene(QPointF(item->width() / 2, item->height() / 2)).toPoint());
}
}

class BrowseFlowTest : public QObject {
    Q_OBJECT
private slots:
    void directAndBatchKeepTheirTargets_data()
    {
        QTest::addColumn<QSize>("size");
        QTest::addColumn<bool>("light");
        for (const auto size : {QSize(564, 520), QSize(884, 520), QSize(1324, 755), QSize(1324, 520)}) {
            for (bool light : {false, true}) {
                const auto name = QString("%1x%2-%3").arg(size.width()).arg(size.height()).arg(light ? "light" : "deep").toLatin1();
                QTest::newRow(name.constData()) << size << light;
            }
        }
    }
    void directAndBatchKeepTheirTargets()
    {
        QFETCH(QSize, size);
        QFETCH(bool, light);
        QQmlEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        QQmlComponent component(&engine, QUrl("qrc:/browse/BrowseFixture.qml"));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QQuickWindow> window(qobject_cast<QQuickWindow *>(component.create()));
        QVERIFY(window);
        window->resize(size);
        window->setProperty("lightTheme", light);
        QVERIFY(QTest::qWaitForWindowExposed(window.get()));
        const auto item = [&](const char *name) { return findItem(window->contentItem(), QString::fromLatin1(name)); };
        auto *page = item("browsePage"); QVERIFY(page);
        auto *target = item("browseTargetPicker"); QVERIFY(target); QVERIFY(target->isVisible());
        QCOMPARE(target->property("currentIndex").toInt(), 0);
        auto *toggle = item("browseBatchToggle"); QVERIFY(toggle); QVERIFY(toggle->isVisible());
        QVERIFY(!item("reviewSelectionButton")->isVisible());
        auto *result = item("browseResult_ocean"); QTRY_VERIFY(result = item("browseResult_ocean"));
        QTest::qWait(30);
        if (qEnvironmentVariableIsSet("PRISMARINE_CAPTURE_DIR"))
            window->grabWindow().save(qEnvironmentVariable("PRISMARINE_CAPTURE_DIR") + "/browse-results-" + QString::number(size.width()) + "x" + QString::number(size.height()) + (light ? "-light.png" : "-deep.png"));
        // With no project chosen there is nothing to pick a version of or install.
        QVERIFY(!item("selectDownloadButton")->isVisible());
        QVERIFY(!item("downloadVersionPicker")->isVisible());
        click(window.get(), result);
        QTest::qWait(30);
        auto *install = item("selectDownloadButton"); QVERIFY(install); QTRY_VERIFY(install->isVisible());
        QCOMPARE(install->property("text").toString(), QString("Install…"));
        auto *version = item("downloadVersionPicker"); QVERIFY(version); version->setProperty("currentIndex", 1);
        install->forceActiveFocus(); QTest::keyClick(window.get(), Qt::Key_Space);
        auto reviews = window->property("reviews").value<QJSValue>().toVariant().toList();
        QCOMPARE(reviews.size(), 1);
        QCOMPARE(reviews.first().toMap().value("target").toString(), "alpha");
        QCOMPARE(reviews.first().toMap().value("version").toString(), "older");
        QVERIFY(!item("reviewSelectionButton")->isVisible());
        const auto bottom = install->mapToScene(QPointF(install->width(), install->height()));
        QVERIFY(bottom.x() <= window->width()); QVERIFY(bottom.y() <= window->height());
        if (qEnvironmentVariableIsSet("PRISMARINE_CAPTURE_DIR")) {
            QTest::qWait(80);
            window->grabWindow().save(qEnvironmentVariable("PRISMARINE_CAPTURE_DIR") + "/browse-project-" + QString::number(size.width()) + "x" + QString::number(size.height()) + (light ? "-light.png" : "-deep.png"));
        }
        if (size.width() < 1000 || size.height() < 650) {
            QTest::qWait(30);
            click(window.get(), item("browseBackToResults"));
            QTRY_VERIFY(toggle->isVisible());
        }
        click(window.get(), toggle);
        result = item("browseResult_ocean");
        click(window.get(), result);
        QTest::qWait(30);
        QTRY_COMPARE(install->property("text").toString(), QString("Add to selection"));
        click(window.get(), install);
        auto *review = item("reviewSelectionButton"); QTRY_VERIFY(review->isEnabled());
        QCOMPARE(review->property("text").toString(), "Review & install (1)");
        QCOMPARE(window->property("reviews").value<QJSValue>().toVariant().toList().size(), 1);
        QVERIFY(install->mapToScene(QPointF(install->width(), install->height())).y() <= window->height());
        click(window.get(), review);
        reviews = window->property("reviews").value<QJSValue>().toVariant().toList();
        QCOMPARE(reviews.size(), 2); QCOMPARE(reviews.last().toMap().value("count").toInt(), 1);
        QVERIFY(review->mapToScene(QPointF(review->width(), review->height())).x() <= window->width());
        // Changing the target must not display or install another instance's batch.
        page->setProperty("targetId", "beta");
        QTRY_VERIFY(!review->isEnabled());
        QCOMPARE(target->property("currentIndex").toInt(), 1);
        page->setProperty("targetId", "alpha"); QTRY_VERIFY(review->isEnabled());
        // No target must look unselected, and datapacks require an explicit world.
        page->setProperty("targetId", "");
        QCOMPARE(target->property("currentIndex").toInt(), -1);
        QVERIFY(!install->isEnabled());
        page->setProperty("targetId", "alpha"); page->setProperty("contentType", "datapack");
        QVERIFY(!install->isEnabled());
        page->setProperty("world", "Survival"); QTRY_VERIFY(install->isEnabled());
        page->setProperty("batchMode", false); click(window.get(), install);
        reviews = window->property("reviews").value<QJSValue>().toVariant().toList();
        QCOMPARE(reviews.last().toMap().value("world").toString(), "Survival");
        QVERIFY2(warnings.isEmpty(), "Unexpected QML warnings");
    }
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Basic");
    BrowseFlowTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "browseflowtest.moc"
