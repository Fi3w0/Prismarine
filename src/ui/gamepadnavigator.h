#pragma once
#include "gamepadstate.h"
#include <QObject>
#include <QPointer>
#include <QVariant>

class QQuickItem;
class QQuickWindow;

// Carries out controller actions in a window. Direction and confirm actions go to the focused
// control as keys first, so sliders, menus and lists keep their own behaviour.
class GamepadNavigator : public QObject {
    Q_OBJECT
public:
    explicit GamepadNavigator(QQuickWindow *window, QObject *parent = nullptr);
    void handle(GamepadState::Action action);
    void scroll(double pixels);
    bool editing() const { return !m_editing.isNull(); }
signals:
    void editingChanged(bool editing);
private:
    static bool isAdjustable(QQuickItem *item);
    static QVariant valueOf(QQuickItem *item);
    void beginEditing(QQuickItem *item);
    void endEditing(bool restore);
    void adjust(QQuickItem *item, GamepadState::Action direction);
    // Delivers through the window, as a keyboard would, unless given a target.
    bool sendKey(int key, QObject *target = nullptr);
    void move(GamepadState::Action direction);
    void activate();
    void back();
    void openContext();
    QQuickItem *focusedControl() const;
    void focus(QQuickItem *item);
    void pageAction(const char *name);
    QQuickWindow *m_window;
    QPointer<QQuickItem> m_editing;
    QVariant m_valueBeforeEditing;
};
