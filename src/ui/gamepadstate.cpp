#include "gamepadstate.h"
#include <QtGlobal>
#include <cmath>

namespace {
constexpr qint64 FirstRepeatMs = 350;
constexpr qint64 RepeatMs = 110;
constexpr qint64 FastFirstRepeatMs = 220;
constexpr qint64 FastRepeatMs = 30;
constexpr double StickPress = 0.55;
constexpr double StickRelease = 0.35;
constexpr double ScrollDeadzone = 0.25;
constexpr double ScrollFastest = 1800;
}

void GamepadState::hold(Action direction, bool held)
{
    m_heldDirections.removeAll(direction);
    if (held) m_heldDirections.append(direction);
}

void GamepadState::setButton(Button button, bool pressed)
{
    bool &state = m_buttons[int(button)];
    if (state == pressed) return;
    state = pressed;
    switch (button) {
    case Button::DpadUp: hold(Action::Up, pressed); return;
    case Button::DpadDown: hold(Action::Down, pressed); return;
    case Button::DpadLeft: hold(Action::Left, pressed); return;
    case Button::DpadRight: hold(Action::Right, pressed); return;
    default: break;
    }
    if (!pressed) return;
    switch (button) {
    case Button::South: m_pending.append(Action::Activate); break;
    case Button::East: m_pending.append(Action::Back); break;
    case Button::North: m_pending.append(Action::Details); break;
    case Button::West: m_pending.append(Action::Context); break;
    case Button::Start: m_pending.append(Action::Menu); break;
    case Button::LeftShoulder: m_pending.append(Action::PreviousPage); break;
    case Button::RightShoulder: m_pending.append(Action::NextPage); break;
    default: break;
    }
}

void GamepadState::setLeftStick(double x, double y)
{
    if (m_stickHeld) {
        const bool horizontal = m_stickDirection == Action::Left || m_stickDirection == Action::Right;
        const double amount = horizontal ? (m_stickDirection == Action::Left ? -x : x) : (m_stickDirection == Action::Up ? -y : y);
        if (amount >= StickRelease) return;
        m_stickHeld = false;
        // The same direction may also be held on the D-pad.
        const bool dpad = (m_stickDirection == Action::Up && m_buttons[int(Button::DpadUp)]) || (m_stickDirection == Action::Down && m_buttons[int(Button::DpadDown)])
            || (m_stickDirection == Action::Left && m_buttons[int(Button::DpadLeft)]) || (m_stickDirection == Action::Right && m_buttons[int(Button::DpadRight)]);
        if (!dpad) hold(m_stickDirection, false);
    }
    if (std::abs(x) < StickPress && std::abs(y) < StickPress) return;
    m_stickDirection = std::abs(x) > std::abs(y) ? (x < 0 ? Action::Left : Action::Right) : (y < 0 ? Action::Up : Action::Down);
    m_stickHeld = true;
    hold(m_stickDirection, true);
}

void GamepadState::setRightStickY(double y)
{
    m_rightY = y;
}

QList<GamepadState::Action> GamepadState::update(qint64 nowMs)
{
    QList<Action> due = m_pending;
    m_pending.clear();
    if (m_heldDirections.isEmpty()) {
        m_hasRepeat = false;
        return due;
    }
    const Action direction = m_heldDirections.last();
    if (!m_hasRepeat || m_repeating != direction) {
        m_hasRepeat = true;
        m_repeating = direction;
        m_nextRepeatMs = nowMs + (m_fastRepeat ? FastFirstRepeatMs : FirstRepeatMs);
        due.append(direction);
    } else if (nowMs >= m_nextRepeatMs) {
        m_nextRepeatMs = nowMs + (m_fastRepeat ? FastRepeatMs : RepeatMs);
        due.append(direction);
    }
    return due;
}

double GamepadState::scrollVelocity() const
{
    const double amount = std::abs(m_rightY);
    if (amount < ScrollDeadzone) return 0;
    const double scaled = (amount - ScrollDeadzone) / (1 - ScrollDeadzone);
    return (m_rightY < 0 ? -1 : 1) * scaled * scaled * ScrollFastest;
}

void GamepadState::reset()
{
    const bool fast = m_fastRepeat;
    *this = GamepadState();
    m_fastRepeat = fast;
}
