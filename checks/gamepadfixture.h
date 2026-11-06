#pragma once
#include "ui/gamepadnavigator.h"
#include "ui/gamepadstate.h"
#include <QCoreApplication>
#include <QObject>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QtTest>
#include <memory>

using Action = GamepadState::Action;

// A real window with a navigator, loaded from a QML snippet, for controller tests.
class GamepadWindowFixture : public QObject {
protected:
    QQmlEngine *m_engine = nullptr;
    std::unique_ptr<QObject> m_root;
    QQuickWindow *m_window = nullptr;
    std::unique_ptr<GamepadNavigator> m_navigator;

    static QQuickItem *find(QQuickItem *from, const QString &name)
    {
        if (from->objectName() == name) return from;
        for (QQuickItem *child : from->childItems())
            if (QQuickItem *found = find(child, name)) return found;
        return nullptr;
    }
    QQuickItem *item(const char *name) const { return find(m_window->contentItem(), QString::fromLatin1(name)); }
    QString focused() const
    {
        for (QQuickItem *current = m_window->activeFocusItem(); current; current = current->parentItem())
            if (!current->objectName().isEmpty()) return current->objectName();
        return {};
    }
    void press(Action action)
    {
        m_navigator->handle(action);
        QCoreApplication::processEvents();
    }
    bool load(const QByteArray &body)
    {
        m_navigator.reset();
        m_root.reset();
        delete m_engine;
        m_engine = new QQmlEngine(this);
        QQmlComponent component(m_engine);
        component.setData("import QtQuick\nimport QtQuick.Controls\nimport QtQuick.Layouts\n"
                          "ApplicationWindow { width: 800; height: 600; visible: true\n"
                          "property var actions: []\nproperty var gamepadEditItem: null\nfunction gamepadAction(name) { actions = actions.concat([name]); }\n" + body + "\n}", QUrl("qrc:/checks/GamepadFixture.qml"));
        if (!component.isReady()) { qWarning() << component.errorString(); return false; }
        m_root.reset(component.create());
        m_window = qobject_cast<QQuickWindow *>(m_root.get());
        if (!m_window || !QTest::qWaitForWindowExposed(m_window)) return false;
        m_window->requestActivate();
        QTest::qWaitForWindowActive(m_window);
        m_navigator = std::make_unique<GamepadNavigator>(m_window);
        return true;
    }
    void closeWindow()
    {
        m_navigator.reset();
        m_root.reset();
        delete m_engine;
        m_engine = nullptr;
    }
};
