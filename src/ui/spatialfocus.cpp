#include "spatialfocus.h"
#include <QQuickItem>
#include <QQuickWindow>
#include <limits>

namespace {
QRectF sceneRect(const QQuickItem *item)
{
    return item->mapRectToScene(QRectF(0, 0, item->width(), item->height()));
}
bool isFlickable(const QQuickItem *item)
{
    return item->inherits("QQuickFlickable");
}
// Clipped by a Flickable is fine, because focus can scroll to it. Anything else stays hidden.
bool clippedAway(const QQuickItem *item)
{
    const QRectF rect = sceneRect(item);
    for (const QQuickItem *parent = item->parentItem(); parent; parent = parent->parentItem()) {
        if (parent->opacity() <= 0) return true;
        if (parent->clip() && !isFlickable(parent) && !parent->inherits("QQuickScrollView") && !sceneRect(parent).intersects(rect)) return true;
    }
    return false;
}
void collect(QQuickItem *item, QList<QQuickItem *> &found)
{
    for (QQuickItem *child : item->childItems()) {
        if (!child->isVisible() || !child->isEnabled() || child->opacity() <= 0) continue;
        if (child->inherits("QQuickOverlay")) continue;
        if (SpatialFocus::isFocusable(child)) {
            if (child->width() > 0 && child->height() > 0 && !clippedAway(child)) found.append(child);
            continue;
        }
        collect(child, found);
    }
}
}

bool SpatialFocus::isFocusable(QQuickItem *item)
{
    // macOS turns off tab focus for buttons by default, so controls are recognised by type too.
    return item->activeFocusOnTab() || item->inherits("QQuickAbstractButton") || item->inherits("QQuickComboBox") || item->inherits("QQuickSlider")
        || item->inherits("QQuickSpinBox") || item->inherits("QQuickTextInput") || item->inherits("QQuickTextEdit");
}

QList<QQuickItem *> SpatialFocus::candidates(QQuickItem *root)
{
    QList<QQuickItem *> found;
    if (root) collect(root, found);
    return found;
}

QQuickItem *SpatialFocus::activeRoot(QQuickWindow *window)
{
    QQuickItem *content = window->contentItem();
    const auto children = content->childItems();
    for (QQuickItem *child : children) {
        if (!child->inherits("QQuickOverlay") || !child->isVisible()) continue;
        const auto popups = child->childItems();
        for (auto it = popups.crbegin(); it != popups.crend(); ++it)
            if ((*it)->isVisible() && (*it)->inherits("QQuickPopupItem") && !candidates(*it).isEmpty()) return *it;
    }
    // Full-window screens drawn over the page, rather than opened as dialogs.
    if (auto *welcome = window->findChild<QQuickItem *>(QStringLiteral("firstRunScreen")); welcome && welcome->isVisible()) return welcome;
    return content;
}

QQuickItem *SpatialFocus::next(QQuickItem *root, QQuickItem *current, GamepadState::Action direction)
{
    using Action = GamepadState::Action;
    const QList<QQuickItem *> items = candidates(root);
    QQuickItem *best = nullptr;
    double bestScore = std::numeric_limits<double>::max();
    if (!current) {
        // A dialog or menu starts at its first control; a page starts near its middle.
        const QPointF start = root->inherits("QQuickPopupItem") ? root->mapToScene(QPointF(0, 0)) : root->mapToScene(QPointF(root->width() / 2, root->height() / 2));
        for (QQuickItem *item : items) {
            const double score = (sceneRect(item).center() - start).manhattanLength();
            if (score < bestScore) { bestScore = score; best = item; }
        }
        return best;
    }
    const QRectF from = sceneRect(current);
    const bool vertical = direction == Action::Up || direction == Action::Down;
    for (QQuickItem *item : items) {
        if (item == current) continue;
        const QRectF to = sceneRect(item);
        double along = 0;
        switch (direction) {
        case Action::Up: if (to.center().y() >= from.center().y() || to.top() >= from.top()) continue; along = from.top() - to.bottom(); break;
        case Action::Down: if (to.center().y() <= from.center().y() || to.bottom() <= from.bottom()) continue; along = to.top() - from.bottom(); break;
        case Action::Left: if (to.center().x() >= from.center().x() || to.left() >= from.left()) continue; along = from.left() - to.right(); break;
        case Action::Right: if (to.center().x() <= from.center().x() || to.right() <= from.right()) continue; along = to.left() - from.right(); break;
        default: return nullptr;
        }
        // Controls directly in line come first; the gap to the side counts more than distance.
        const double across = vertical ? qMax(0.0, qMax(from.left() - to.right(), to.left() - from.right()))
                                       : qMax(0.0, qMax(from.top() - to.bottom(), to.top() - from.bottom()));
        const double centres = vertical ? qAbs(to.center().x() - from.center().x()) : qAbs(to.center().y() - from.center().y());
        const double score = qMax(0.0, along) + across * 4 + centres * 0.1;
        if (score < bestScore) { bestScore = score; best = item; }
    }
    return best;
}

QQuickItem *SpatialFocus::nearestFlickable(QQuickItem *item)
{
    for (; item; item = item->parentItem())
        if (isFlickable(item)) return item;
    return nullptr;
}

void SpatialFocus::scrollIntoView(QQuickItem *item)
{
    constexpr double Margin = 24;
    for (QQuickItem *flickable = nearestFlickable(item->parentItem()); flickable; flickable = nearestFlickable(flickable->parentItem())) {
        const QRectF rect = flickable->mapRectFromItem(item, QRectF(0, 0, item->width(), item->height()));
        const double contentY = flickable->property("contentY").toDouble();
        double target = contentY;
        if (rect.bottom() + Margin > flickable->height()) target += rect.bottom() + Margin - flickable->height();
        if (rect.top() - Margin < 0) target += rect.top() - Margin;
        const double origin = flickable->property("originY").toDouble();
        const double highest = origin + qMax(0.0, flickable->property("contentHeight").toDouble() - flickable->height());
        target = qBound(origin, target, qMax(origin, highest));
        if (target != contentY) flickable->setProperty("contentY", target);
    }
}
