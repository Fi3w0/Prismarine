#include "gamepadnavigator.h"
#include "spatialfocus.h"
#include <QCoreApplication>
#include <QKeyEvent>
#include <QQuickItem>
#include <QQuickWindow>
#include <QScopeGuard>

GamepadNavigator::GamepadNavigator(QQuickWindow *window, QObject *parent) : QObject(parent), m_window(window)
{
    // Focus moved some other way, such as a mouse click: the new value stays.
    connect(window, &QQuickWindow::activeFocusItemChanged, this, [this] {
        if (m_editing && focusedControl() != m_editing) endEditing(false);
    });
}

bool GamepadNavigator::isAdjustable(QQuickItem *item)
{
    return item->inherits("QQuickSlider") || item->inherits("QQuickSpinBox") || item->property("gamepadAdjustable").toBool();
}

QVariant GamepadNavigator::valueOf(QQuickItem *item)
{
    return item->property("gamepadAdjustable").toBool() ? item->property("gamepadValue") : item->property("value");
}

void GamepadNavigator::beginEditing(QQuickItem *item)
{
    m_editing = item;
    m_valueBeforeEditing = valueOf(item);
    m_window->setProperty("gamepadEditItem", QVariant::fromValue(item));
    emit editingChanged(true);
}

void GamepadNavigator::endEditing(bool restore)
{
    if (QQuickItem *item = m_editing) {
        if (restore) {
            if (item->property("gamepadAdjustable").toBool()) {
                QMetaObject::invokeMethod(item, "gamepadRestore", Q_ARG(QVariant, m_valueBeforeEditing));
            } else if (valueOf(item) != m_valueBeforeEditing) {
                // Through the signals a user's change would send, so whatever uses the value follows.
                item->setProperty("value", m_valueBeforeEditing);
                QMetaObject::invokeMethod(item, item->inherits("QQuickSpinBox") ? "valueModified" : "moved");
            }
        }
    }
    m_editing = nullptr;
    m_window->setProperty("gamepadEditItem", QVariant::fromValue<QObject *>(nullptr));
    emit editingChanged(false);
}

void GamepadNavigator::adjust(QQuickItem *item, GamepadState::Action direction)
{
    using Action = GamepadState::Action;
    const bool isSpinBox = item->inherits("QQuickSpinBox");
    const int key = direction == Action::Up ? Qt::Key_Up : direction == Action::Down ? Qt::Key_Down
        : direction == Action::Left ? (isSpinBox ? Qt::Key_Down : Qt::Key_Left) : (isSpinBox ? Qt::Key_Up : Qt::Key_Right);
    sendKey(key, item);
}

bool GamepadNavigator::sendKey(int key, QObject *target)
{
    if (!m_window->activeFocusItem()) return false;
    m_window->setProperty("gamepadKey", true);
    const auto restore = qScopeGuard([this] { m_window->setProperty("gamepadKey", false); });
    QKeyEvent press(QEvent::KeyPress, key, Qt::NoModifier);
    press.setAccepted(false);
    QCoreApplication::sendEvent(target ? target : m_window, &press);
    const bool accepted = press.isAccepted();
    QKeyEvent release(QEvent::KeyRelease, key, Qt::NoModifier);
    release.setAccepted(false);
    QCoreApplication::sendEvent(target ? target : m_window, &release);
    return accepted;
}

QQuickItem *GamepadNavigator::focusedControl() const
{
    QQuickItem *root = SpatialFocus::activeRoot(m_window);
    for (QQuickItem *item = m_window->activeFocusItem(); item; item = item->parentItem()) {
        if (!SpatialFocus::isFocusable(item)) continue;
        if (!item->isVisible() || !item->isEnabled()) return nullptr;
        // An open dropdown keeps focus on itself, outside its own list.
        if (item->inherits("QQuickComboBox") && item->property("down").toBool()) return item;
        for (QQuickItem *parent = item; parent; parent = parent->parentItem())
            if (parent == root) return item;
        return nullptr;
    }
    return nullptr;
}

void GamepadNavigator::focus(QQuickItem *item)
{
    if (!item) return;
    item->forceActiveFocus(Qt::TabFocusReason);
    SpatialFocus::scrollIntoView(item);
}

void GamepadNavigator::move(GamepadState::Action direction)
{
    using Action = GamepadState::Action;
    QQuickItem *current = focusedControl();
    // The first press only shows where focus is.
    if (!current) { focus(SpatialFocus::next(SpatialFocus::activeRoot(m_window), nullptr, direction)); return; }
    if (current == m_editing) { adjust(current, direction); return; }
    const bool vertical = direction == Action::Up || direction == Action::Down;
    const bool isOpenList = current->inherits("QQuickComboBox") && current->property("down").toBool();
    // Values never change just by passing through. Adjusting one starts with the confirm button.
    const bool skipKey = isAdjustable(current) || (current->inherits("QQuickComboBox") && !isOpenList);
    if (!skipKey) {
        const int key = direction == Action::Up ? Qt::Key_Up : direction == Action::Down ? Qt::Key_Down : direction == Action::Left ? Qt::Key_Left : Qt::Key_Right;
        // Straight to the control: a surrounding ScrollView would otherwise claim every arrow key.
        if (sendKey(key, current)) {
            if (QQuickItem *now = focusedControl()) SpatialFocus::scrollIntoView(now);
            return;
        }
    }
    if (QQuickItem *target = SpatialFocus::next(SpatialFocus::activeRoot(m_window), current, direction)) { focus(target); return; }
    if (vertical) scroll(direction == Action::Up ? -160 : 160);
}

void GamepadNavigator::activate()
{
    QQuickItem *current = focusedControl();
    if (!current) { focus(SpatialFocus::next(SpatialFocus::activeRoot(m_window), nullptr, GamepadState::Action::Down)); return; }
    // Text needs an on-screen keyboard, which does not exist yet; a typed space would be wrong.
    if (current->inherits("QQuickTextInput") || current->inherits("QQuickTextEdit")) return;
    if (isAdjustable(current)) {
        if (current == m_editing) endEditing(false); else beginEditing(current);
        return;
    }
    if (sendKey(Qt::Key_Space)) return;
    if (sendKey(Qt::Key_Return)) return;
    QMetaObject::invokeMethod(current, "clicked");
}

void GamepadNavigator::back()
{
    if (m_editing) { endEditing(true); return; }
    if (sendKey(Qt::Key_Escape)) return;
    QQuickItem *root = SpatialFocus::activeRoot(m_window);
    if (root->inherits("QQuickPopupItem")) return;
    pageAction("back");
}

void GamepadNavigator::openContext()
{
    // The controller's right click: the focused control's own menu, or the page's.
    QQuickItem *current = focusedControl();
    for (QQuickItem *item = current; item; item = item->parentItem()) {
        if (item->metaObject()->indexOfMethod("gamepadContext()") >= 0) {
            QMetaObject::invokeMethod(item, "gamepadContext");
            return;
        }
    }
    pageAction("context");
}

void GamepadNavigator::pageAction(const char *name)
{
    // Anything open on top of the page has to be dealt with first. Otherwise a second menu
    // could open behind this one, or a game could start from behind a dialog.
    if (SpatialFocus::activeRoot(m_window) != m_window->contentItem()) return;
    if (m_window->metaObject()->indexOfMethod("gamepadAction(QVariant)") < 0) return;
    QMetaObject::invokeMethod(m_window, "gamepadAction", Q_ARG(QVariant, QString::fromLatin1(name)));
}

void GamepadNavigator::handle(GamepadState::Action action)
{
    using Action = GamepadState::Action;
    // Page buttons leave the control behind, so finish adjusting first and keep the value.
    if (m_editing && (action == Action::Details || action == Action::Context || action == Action::Menu || action == Action::PreviousPage || action == Action::NextPage)) endEditing(false);
    switch (action) {
    case Action::Up: case Action::Down: case Action::Left: case Action::Right: move(action); break;
    case Action::Activate: activate(); break;
    case Action::Back: back(); break;
    case Action::Details: pageAction("details"); break;
    case Action::Context: openContext(); break;
    case Action::Menu: pageAction("menu"); break;
    case Action::PreviousPage: pageAction("previousPage"); break;
    case Action::NextPage: pageAction("nextPage"); break;
    }
}

void GamepadNavigator::scroll(double pixels)
{
    QQuickItem *flickable = SpatialFocus::nearestFlickable(focusedControl());
    if (!flickable) {
        // Nothing focused inside a list: use whatever sits in the middle of the window.
        QQuickItem *item = m_window->contentItem();
        for (QPointF point(m_window->width() / 2.0, m_window->height() / 2.0); item;) {
            if (item->inherits("QQuickFlickable")) flickable = item;
            QQuickItem *child = item->childAt(item->mapFromScene(point).x(), item->mapFromScene(point).y());
            if (!child) break;
            item = child;
        }
    }
    if (!flickable) return;
    const double origin = flickable->property("originY").toDouble();
    const double highest = origin + qMax(0.0, flickable->property("contentHeight").toDouble() - flickable->height());
    flickable->setProperty("contentY", qBound(origin, flickable->property("contentY").toDouble() + pixels, qMax(origin, highest)));
}
