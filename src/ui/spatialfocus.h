#pragma once
#include "gamepadstate.h"
#include <QList>

class QQuickItem;
class QQuickWindow;

// Moves keyboard focus by position on screen, so every page and dialog works with a controller
// without describing its own navigation order.
namespace SpatialFocus {
bool isFocusable(QQuickItem *item);
QList<QQuickItem *> candidates(QQuickItem *root);
// What navigation is limited to: the top open dialog, or else the page and navigation.
QQuickItem *activeRoot(QQuickWindow *window);
// The best control from current in this direction, or nullptr. Without a current control,
// the one nearest the middle of root.
QQuickItem *next(QQuickItem *root, QQuickItem *current, GamepadState::Action direction);
QQuickItem *nearestFlickable(QQuickItem *item);
void scrollIntoView(QQuickItem *item);
}
