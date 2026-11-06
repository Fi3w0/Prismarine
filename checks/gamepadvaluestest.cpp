#include "gamepadfixture.h"
#include <QGuiApplication>
#include <QQuickStyle>

// Sliders, number boxes, dropdowns and custom controls keep their values until adjusted on purpose.
class GamepadValuesTest : public GamepadWindowFixture {
    Q_OBJECT
private slots:
    void cleanup() { closeWindow(); }
    void passingThroughControlsLeavesTheirValuesAlone()
    {
        QVERIFY(load(R"(
            Button { objectName: "top"; x: 20; y: 20; width: 200; height: 40 }
            ComboBox { objectName: "combo"; x: 20; y: 80; width: 200; height: 40; model: ["one", "two", "three"] }
            Slider { objectName: "slider"; x: 20; y: 140; width: 200; height: 40; from: 0; to: 10; stepSize: 1; value: 5 }
            SpinBox { objectName: "spin"; x: 20; y: 200; width: 200; height: 40; from: 0; to: 10; value: 5 }
            Button { objectName: "bottom"; x: 20; y: 260; width: 200; height: 40 }
        )"));
        item("top")->forceActiveFocus();
        for (const char *name : {"combo", "slider", "spin", "bottom"}) {
            press(Action::Down);
            QCOMPARE(focused(), QString::fromLatin1(name));
        }
        for (const char *name : {"spin", "slider", "combo", "top"}) {
            press(Action::Up);
            QCOMPARE(focused(), QString::fromLatin1(name));
        }
        QCOMPARE(item("combo")->property("currentIndex").toInt(), 0);
        QCOMPARE(item("slider")->property("value").toDouble(), 5.0);
        QCOMPARE(item("spin")->property("value").toInt(), 5);
    }
    void valuesChangeOnlyAfterConfirm()
    {
        QVERIFY(load(R"(
            Button { objectName: "left"; x: 20; y: 140; width: 100; height: 40 }
            Slider { objectName: "slider"; property int moves: 0; x: 200; y: 140; width: 200; height: 40; from: 0; to: 10; stepSize: 1; value: 5; onMoved: ++moves }
            Button { objectName: "right"; x: 500; y: 140; width: 100; height: 40 }
            SpinBox { objectName: "spin"; property int edits: 0; x: 200; y: 300; width: 200; height: 40; from: 0; to: 10; value: 5; onValueModified: ++edits }
        )"));
        auto *slider = item("slider");
        slider->forceActiveFocus();
        // Not adjusting: directions just leave, in every direction.
        press(Action::Right);
        QCOMPARE(focused(), QStringLiteral("right"));
        press(Action::Left);
        QCOMPARE(focused(), QStringLiteral("slider"));
        press(Action::Left);
        QCOMPARE(focused(), QStringLiteral("left"));
        press(Action::Right);
        QCOMPARE(slider->property("value").toDouble(), 5.0);
        QVERIFY(!m_navigator->editing());

        // Confirm starts adjusting, directions change it, confirm accepts.
        press(Action::Activate);
        QVERIFY(m_navigator->editing());
        QCOMPARE(m_root->property("gamepadEditItem").value<QObject *>(), slider);
        press(Action::Right);
        press(Action::Right);
        QCOMPARE(slider->property("value").toDouble(), 7.0);
        QCOMPARE(focused(), QStringLiteral("slider"));
        press(Action::Activate);
        QVERIFY(!m_navigator->editing());
        QCOMPARE(m_root->property("gamepadEditItem").value<QObject *>(), nullptr);
        QCOMPARE(slider->property("value").toDouble(), 7.0);
        press(Action::Right);
        QCOMPARE(focused(), QStringLiteral("right"));
        QCOMPARE(slider->property("value").toDouble(), 7.0);

        // Cancel restores, and tells whatever uses the value.
        slider->forceActiveFocus();
        press(Action::Activate);
        press(Action::Left);
        press(Action::Left);
        QCOMPARE(slider->property("value").toDouble(), 5.0);
        const int moves = slider->property("moves").toInt();
        press(Action::Back);
        QVERIFY(!m_navigator->editing());
        QCOMPARE(slider->property("value").toDouble(), 7.0);
        QCOMPARE(slider->property("moves").toInt(), moves + 1);
        QVERIFY(m_root->property("actions").toStringList().isEmpty());

        // Number boxes: all four directions, and cancel.
        auto *spin = item("spin");
        spin->forceActiveFocus();
        press(Action::Left);
        QCOMPARE(spin->property("value").toInt(), 5);
        spin->forceActiveFocus();
        press(Action::Activate);
        press(Action::Right);
        press(Action::Up);
        QCOMPARE(spin->property("value").toInt(), 7);
        press(Action::Left);
        QCOMPARE(spin->property("value").toInt(), 6);
        press(Action::Back);
        QCOMPARE(spin->property("value").toInt(), 5);
    }
    void customControlsCanBeAdjustedToo()
    {
        QVERIFY(load(R"(
            Button { objectName: "below"; x: 20; y: 400; width: 100; height: 40 }
            Rectangle {
                objectName: "square"; x: 20; y: 20; width: 200; height: 200; activeFocusOnTab: true
                property real amount: 0.5
                readonly property bool gamepadAdjustable: true
                readonly property var gamepadValue: [amount]
                function gamepadRestore(value) { amount = value[0]; }
                Keys.onDownPressed: amount -= 0.1
                Keys.onUpPressed: amount += 0.1
            }
        )"));
        auto *square = item("square");
        square->forceActiveFocus();
        press(Action::Down);
        QCOMPARE(focused(), QStringLiteral("below"));
        QCOMPARE(square->property("amount").toDouble(), 0.5);
        press(Action::Up);
        QCOMPARE(focused(), QStringLiteral("square"));
        press(Action::Activate);
        press(Action::Down);
        QVERIFY(qAbs(square->property("amount").toDouble() - 0.4) < 0.001);
        QCOMPARE(focused(), QStringLiteral("square"));
        press(Action::Back);
        QCOMPARE(square->property("amount").toDouble(), 0.5);
        press(Action::Down);
        QCOMPARE(focused(), QStringLiteral("below"));
    }
    void adjustingEndsWhenFocusLeavesAnotherWay()
    {
        QVERIFY(load(R"(
            Slider { objectName: "slider"; x: 20; y: 20; width: 200; height: 40; from: 0; to: 10; stepSize: 1; value: 5 }
            Button { objectName: "other"; x: 20; y: 100; width: 100; height: 40 }
        )"));
        auto *slider = item("slider");
        slider->forceActiveFocus();
        press(Action::Activate);
        press(Action::Right);
        QVERIFY(m_navigator->editing());
        item("other")->forceActiveFocus();
        QVERIFY(!m_navigator->editing());
        QCOMPARE(slider->property("value").toDouble(), 6.0);
        // Page buttons finish adjusting too, keeping the value.
        slider->forceActiveFocus();
        press(Action::Activate);
        press(Action::NextPage);
        QVERIFY(!m_navigator->editing());
        QCOMPARE(m_root->property("actions").toStringList(), QStringList{"nextPage"});
    }
    void dropdownsOpenChooseAndClose()
    {
        QVERIFY(load(R"(
            ComboBox { objectName: "combo"; x: 20; y: 80; width: 200; height: 40; model: ["one", "two", "three"] }
            Button { objectName: "below"; x: 20; y: 300; width: 200; height: 40 }
        )"));
        auto *combo = item("combo");
        combo->forceActiveFocus();
        press(Action::Activate);
        QTRY_VERIFY(combo->property("down").toBool());
        press(Action::Down);
        QCOMPARE(combo->property("highlightedIndex").toInt(), 1);
        press(Action::Activate);
        QTRY_VERIFY(!combo->property("down").toBool());
        QCOMPARE(combo->property("currentIndex").toInt(), 1);
        // Back cancels without choosing.
        press(Action::Activate);
        QTRY_VERIFY(combo->property("down").toBool());
        press(Action::Down);
        press(Action::Back);
        QTRY_VERIFY(!combo->property("down").toBool());
        QCOMPARE(combo->property("currentIndex").toInt(), 1);
        press(Action::Down);
        QCOMPARE(focused(), QStringLiteral("below"));
    }
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Basic");
    GamepadValuesTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "gamepadvaluestest.moc"
