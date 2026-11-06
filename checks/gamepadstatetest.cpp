#include "ui/gamepadstate.h"
#include <QtTest>

using Action = GamepadState::Action;
using Button = GamepadState::Button;

// Button timing and direction rules, with no window or controller.
class GamepadStateTest : public QObject {
    Q_OBJECT
private slots:
    void buttonsFireOncePerPress()
    {
        GamepadState state;
        state.setButton(Button::South, true);
        QCOMPARE(state.update(0), QList<Action>{Action::Activate});
        QVERIFY(state.update(500).isEmpty());
        state.setButton(Button::South, false);
        QVERIFY(state.update(510).isEmpty());
        state.setButton(Button::South, true);
        QCOMPARE(state.update(520), QList<Action>{Action::Activate});
    }
    void heldDirectionsRepeat()
    {
        GamepadState state;
        state.setButton(Button::DpadDown, true);
        QCOMPARE(state.update(0), QList<Action>{Action::Down});
        QVERIFY(state.update(349).isEmpty());
        QCOMPARE(state.update(350), QList<Action>{Action::Down});
        QVERIFY(state.update(400).isEmpty());
        QCOMPARE(state.update(460), QList<Action>{Action::Down});
        state.setButton(Button::DpadDown, false);
        QVERIFY(state.update(1000).isEmpty());
    }
    void newestDirectionWinsOnDiagonals()
    {
        // The test controller reports two D-pad directions at once on a diagonal.
        GamepadState state;
        state.setButton(Button::DpadUp, true);
        QCOMPARE(state.update(0), QList<Action>{Action::Up});
        state.setButton(Button::DpadRight, true);
        QCOMPARE(state.update(16), QList<Action>{Action::Right});
        QVERIFY(state.update(32).isEmpty());
        state.setButton(Button::DpadRight, false);
        QCOMPARE(state.update(48), QList<Action>{Action::Up});
    }
    void stickNeedsAFirmPushAndAFullRelease()
    {
        GamepadState state;
        state.setLeftStick(0.4, 0);
        QVERIFY(state.update(0).isEmpty());
        state.setLeftStick(0.7, 0.2);
        QCOMPARE(state.update(16), QList<Action>{Action::Right});
        // Sagging below the press level, but not to release, is not a new press.
        state.setLeftStick(0.45, 0);
        QVERIFY(state.update(32).isEmpty());
        state.setLeftStick(0.1, 0);
        QVERIFY(state.update(48).isEmpty());
        state.setLeftStick(0.7, 0);
        QCOMPARE(state.update(64), QList<Action>{Action::Right});
        state.setLeftStick(0, 0);
        state.update(80);
        state.setLeftStick(0.3, -0.8);
        QCOMPARE(state.update(96), QList<Action>{Action::Up});
    }
    void resetDropsWhatIsHeld()
    {
        GamepadState state;
        state.setButton(Button::DpadDown, true);
        state.update(0);
        state.reset();
        QVERIFY(state.update(1000).isEmpty());
        // Still holding the button after coming back is a fresh press only when reported again.
        state.setButton(Button::DpadDown, true);
        QCOMPARE(state.update(1100), QList<Action>{Action::Down});
    }
    void rightStickScrollsWithADeadzone()
    {
        GamepadState state;
        state.setRightStickY(0.2);
        QCOMPARE(state.scrollVelocity(), 0.0);
        state.setRightStickY(1);
        QCOMPARE(state.scrollVelocity(), 1800.0);
        state.setRightStickY(-1);
        QCOMPARE(state.scrollVelocity(), -1800.0);
    }
    void adjustingRepeatsFaster()
    {
        GamepadState state;
        state.setFastRepeat(true);
        state.setButton(Button::DpadRight, true);
        QCOMPARE(state.update(0), QList<Action>{Action::Right});
        QVERIFY(state.update(219).isEmpty());
        QCOMPARE(state.update(220), QList<Action>{Action::Right});
        QCOMPARE(state.update(250), QList<Action>{Action::Right});
        state.reset();
        state.setButton(Button::DpadRight, true);
        state.update(1000);
        QCOMPARE(state.update(1220), QList<Action>{Action::Right});
    }
};

QTEST_APPLESS_MAIN(GamepadStateTest)
#include "gamepadstatetest.moc"
