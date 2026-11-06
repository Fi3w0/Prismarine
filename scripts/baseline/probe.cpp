// Linux-only diagnostic loaded into the release executable with LD_PRELOAD.
// It exercises disposable fixtures; it does not implement launcher behavior.
#include <QBitArray>
#include <QCoreApplication>
#include <QElapsedTimer>
#include <QGuiApplication>
#include <QJsonDocument>
#include <QJsonObject>
#include <QQuickItem>
#include <QQuickWindow>
#include <QQmlContext>
#include <QQmlEngine>
#include <QJsonArray>
#include <QTest>
#include <QTimer>
#include <atomic>
#include <functional>
#include <memory>
#include <deque>

namespace {
QElapsedTimer clockTime;
QQuickWindow *window = nullptr;
struct Step { int delay; QString name; std::function<void()> action; };
std::deque<Step> steps;
int previousDeadline = 0;
void record(QJsonObject values)
{
    values.insert("elapsed_ms", double(clockTime.nsecsElapsed()) / 1000000);
    qInfo().noquote() << "BASELINE" << QJsonDocument(values).toJson(QJsonDocument::Compact);
}
QQuickItem *findItem(QQuickItem *root, const QString &name)
{
    if (root->objectName() == name) return root;
    for (auto *child : root->childItems())
        if (auto *found = findItem(child, name)) return found;
    return nullptr;
}
QJsonObject focus()
{
    const auto *item = window->activeFocusItem();
    return {{"name", item ? item->objectName() : ""},
            {"type", item ? item->metaObject()->className() : ""},
            {"text", item ? item->property("text").toString() : ""}};
}
void nextStep()
{
    if (steps.empty()) return;
    const auto step = steps.front();
    steps.pop_front();
    QTimer::singleShot(step.delay, qApp, [step] {
        QElapsedTimer duration;
        duration.start();
        record({{"event", "action_start"}, {"name", step.name}});
        step.action();
        record({{"event", "action"}, {"name", step.name},
                {"call_ms", double(duration.nsecsElapsed()) / 1000000}, {"focus", focus()}});
        nextStep();
    });
}
void later(int milliseconds, const QString &name, std::function<void()> action)
{
    steps.push_back({milliseconds - previousDeadline, name, action});
    previousDeadline = milliseconds;
}
void navigate(const QString &page)
{
    const bool ok = QMetaObject::invokeMethod(window, "navigate", Q_ARG(QVariant, QVariant(page)));
    record({{"event", "navigate"}, {"page", page}, {"invoked", ok}});
}
void runningObjects()
{
    for (auto *object : window->findChildren<QObject *>()) {
        if (!object->property("running").toBool()) continue;
        QJsonArray parents;
        auto *parent = object->parent();
        for (int level = 0; parent && level < 5; ++level, parent = parent->parent())
            parents.append(QJsonObject{{"type", parent->metaObject()->className()},
                {"name", parent->objectName()}, {"visible", parent->property("visible").toBool()}});
        auto *context = qmlContext(object);
        record({{"event", "running_object"}, {"type", object->metaObject()->className()},
                {"source", context ? context->baseUrl().toString() : ""}, {"parents", parents}});
    }
}
void start()
{
    clockTime.start();
    QTimer::singleShot(0, qApp, [] {
        for (auto *candidate : QGuiApplication::topLevelWindows()) {
            if ((window = qobject_cast<QQuickWindow *>(candidate))) break;
        }
        if (!window) { record({{"event", "error"}, {"message", "No QQuickWindow"}}); qApp->exit(2); return; }
        record({{"event", "window_ready"}, {"focus", focus()}, {"width", window->width()},
                {"height", window->height()}, {"device_pixel_ratio", window->devicePixelRatio()}});
        auto firstFrame = std::make_shared<std::atomic<bool>>(true);
        QObject::connect(window, &QQuickWindow::frameSwapped, window, [firstFrame] {
            if (firstFrame->exchange(false)) record({{"event", "first_frame_swapped"}});
        }, Qt::DirectConnection);
        auto *heartbeat = new QTimer(qApp);
        auto previous = std::make_shared<qint64>(clockTime.elapsed());
        QObject::connect(heartbeat, &QTimer::timeout, qApp, [previous] {
            const auto now = clockTime.elapsed();
            if (now - *previous > 50)
                record({{"event", "event_loop_gap"}, {"gap_ms", double(now - *previous)}});
            *previous = now;
        });
        heartbeat->start(16);
        later(2000, "home_idle", [] { runningObjects(); });
        later(5000, "library", [] { navigate("library"); });
        later(5800, "library_idle", [] {});
        later(8800, "library_arrow", [] {
            auto *grid = findItem(window->contentItem(), "coverGrid");
            if (!grid) { record({{"event", "error"}, {"message", "No coverGrid"}}); return; }
            record({{"event", "selection_before"}, {"selected", window->property("selected").toInt()}});
            grid->forceActiveFocus();
            QTest::keyClick(window, Qt::Key_Right);
            record({{"event", "selection_after"}, {"selected", window->property("selected").toInt()}});
        });
        later(9200, "palette_open", [] { QTest::keyClick(window, Qt::Key_K, Qt::ControlModifier); });
        later(9600, "palette_close", [] { QTest::keyClick(window, Qt::Key_Escape); });
        later(10000, "tab_walk", [] {
            for (int index = 0; index < 24; ++index) {
                QTest::keyClick(window, Qt::Key_Tab);
                record({{"event", "tab_focus"}, {"index", index}, {"focus", focus()}});
            }
        });
        later(11000, "settings", [] { navigate("settings"); });
        later(12000, "accounts", [] { navigate("accounts"); });
        later(13500, "instance_mods", [] {
            QMetaObject::invokeMethod(window, "openInstance", Q_ARG(QVariant, QVariant("fixture-000")),
                                      Q_ARG(QVariant, QVariant("mods")));
        });
        later(15000, "library_again", [] { navigate("library"); });
        later(16000, "reload", [] { QMetaObject::invokeMethod(window, "reloadLibrary"); });
        later(17000, "hidden_idle", [] { window->hide(); });
        later(20000, "show", [] { window->show(); });
        later(21000, "finish", [] { qApp->quit(); });
        nextStep();
    });
}
}
Q_COREAPP_STARTUP_FUNCTION(start)
