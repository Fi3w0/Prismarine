// A Qt plugin Prismarine loads into the Prism Launcher it starts, so launches stay free of
// Prism's own windows unless the classic launcher window is open. It does the same as
// packaging/prism-patch without rebuilding Prism: Qt loads it from QT_PLUGIN_PATH when
// QT_QPA_GENERIC_PLUGINS names "prismarinequiet". It only looks at Prism's window classes
// by name; when Prism renames them, the windows simply show again.
#include <QApplication>
#include <QEvent>
#include <QGenericPlugin>
#include <QPointer>
#include <QTimer>
#include <QWidget>

namespace {
bool mainWindowVisible()
{
    for (QWidget *widget : QApplication::topLevelWidgets())
        if (widget->inherits("MainWindow") && widget->isVisible() && !widget->testAttribute(Qt::WA_DontShowOnScreen)) return true;
    return false;
}

class QuietFilter : public QObject {
public:
    using QObject::QObject;
    bool eventFilter(QObject *object, QEvent *event) override
    {
        // Show reaches the widget before its window is mapped, so it can still stay off screen.
        if (event->type() != QEvent::Show || !object->isWidgetType()) return false;
        auto *widget = static_cast<QWidget *>(object);
        if (!widget->isWindow() || mainWindowVisible()) return false;
        if (widget->inherits("ProgressDialog")) {
            // "Please wait…" while signing in and preparing: the dialog keeps running its task
            // (closing it would cancel the launch), it is just never put on screen.
            widget->setAttribute(Qt::WA_DontShowOnScreen);
            qInfo("Prismarine: keeping Prism's progress dialog off screen");
        } else if (widget->inherits("InstanceWindow")) {
            // The console: closed the normal way, so Prism's window bookkeeping stays right.
            widget->setAttribute(Qt::WA_DontShowOnScreen);
            QTimer::singleShot(0, widget, [window = QPointer<QWidget>(widget)] { if (window) window->close(); });
            qInfo("Prismarine: closed Prism's console window");
        }
        return false;
    }
};
}

class PrismQuietPlugin : public QGenericPlugin {
    Q_OBJECT
    Q_PLUGIN_METADATA(IID QGenericPluginFactoryInterface_iid FILE "prismquiet.json")
public:
    QObject *create(const QString &key, const QString &) override
    {
        // Prism is a widgets application; anything else is left alone.
        if (key.compare("prismarinequiet", Qt::CaseInsensitive) != 0 || !qobject_cast<QApplication *>(QCoreApplication::instance()))
            return nullptr;
        // Qt deletes what a generic plugin returns when the application ends, so no parent.
        auto *filter = new QuietFilter;
        QCoreApplication::instance()->installEventFilter(filter);
        qInfo("Prismarine: quiet launch plugin active");
        return filter;
    }
};

#include "prismquiet.moc"
