#pragma once
#include <QList>

// Turns raw controller state into navigation actions. Knows nothing about SDL or the window,
// so held-button repeat and direction choices can be tested without a controller.
class GamepadState {
public:
    enum class Action { Up, Down, Left, Right, Activate, Back, Details, Context, Menu, PreviousPage, NextPage };
    enum class Button { South, East, North, West, Start, LeftShoulder, RightShoulder, DpadUp, DpadDown, DpadLeft, DpadRight };

    void setButton(Button button, bool pressed);
    // Axes run from -1 to 1, with negative y pointing up.
    void setLeftStick(double x, double y);
    void setRightStickY(double y);
    // The actions due at this time, in order.
    QList<Action> update(qint64 nowMs);
    // Pixels per second to scroll, from the right stick. Positive scrolls down.
    double scrollVelocity() const;
    // Forgets everything held, for example when the window loses focus.
    void reset();
    // Faster repeat while adjusting a value, so a full sweep does not take long.
    void setFastRepeat(bool fast) { m_fastRepeat = fast; }

private:
    void hold(Action direction, bool held);
    QList<Action> m_pending;
    QList<Action> m_heldDirections; // oldest first; the newest one wins, so diagonals stay predictable
    bool m_buttons[11] = {};
    bool m_stickHeld = false;
    Action m_stickDirection = Action::Up;
    double m_rightY = 0;
    bool m_hasRepeat = false;
    bool m_fastRepeat = false;
    Action m_repeating = Action::Up;
    qint64 m_nextRepeatMs = 0;
};
