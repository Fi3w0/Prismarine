#include "ui/gamepadnavigator.h"
#include "ui/gamepadstate.h"
#include "ui/spatialfocus.h"
#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickStyle>
#include <QQuickWindow>
#include <QtTest>
#include <memory>

using Action = GamepadState::Action;
using Button = GamepadState::Button;

class GamepadNavigationTest : public QObject {
    Q_OBJECT
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

private slots:
    void cleanup()
    {
        m_navigator.reset();
        m_root.reset();
        delete m_engine;
        m_engine = nullptr;
    }

    // --- Pad state, no window needed.
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

    // --- Focus movement in a real window.
    void movesByPositionAndSkipsWhatCannotBeUsed()
    {
        QVERIFY(load(R"(
            Button { objectName: "a"; x: 20; y: 20; width: 100; height: 40; text: "a" }
            Button { objectName: "b"; x: 200; y: 20; width: 100; height: 40; text: "b" }
            Button { objectName: "off"; x: 400; y: 20; width: 100; height: 40; enabled: false }
            Button { objectName: "hidden"; x: 500; y: 20; width: 100; height: 40; visible: false }
            Button { objectName: "c"; x: 600; y: 20; width: 100; height: 40; text: "c" }
            Button { objectName: "d"; x: 20; y: 200; width: 100; height: 40; text: "d" }
        )"));
        item("a")->forceActiveFocus();
        press(Action::Right);
        QCOMPARE(focused(), QStringLiteral("b"));
        press(Action::Right);
        QCOMPARE(focused(), QStringLiteral("c"));
        press(Action::Left);
        press(Action::Left);
        QCOMPARE(focused(), QStringLiteral("a"));
        press(Action::Down);
        QCOMPARE(focused(), QStringLiteral("d"));
        press(Action::Up);
        QCOMPARE(focused(), QStringLiteral("a"));
        // Nothing further that way: focus stays put.
        press(Action::Left);
        QCOMPARE(focused(), QStringLiteral("a"));
        QVERIFY(item("a")->property("visualFocus").toBool());
    }
    void firstPressOnlyShowsFocus()
    {
        QVERIFY(load(R"(Button { objectName: "only"; property int clicks: 0; x: 300; y: 200; width: 100; height: 40; onClicked: ++clicks })"));
        QVERIFY(focused() != QStringLiteral("only"));
        press(Action::Activate);
        QCOMPARE(focused(), QStringLiteral("only"));
        QCOMPARE(item("only")->property("clicks").toInt(), 0);
        press(Action::Activate);
        QCOMPARE(item("only")->property("clicks").toInt(), 1);
    }
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
    void dialogsHoldFocusAndBackClosesThem()
    {
        QVERIFY(load(R"(
            Button { objectName: "page"; x: 20; y: 20; width: 100; height: 40; property int clicks: 0; onClicked: { ++clicks; dialog.open(); } }
            Button { objectName: "besidePage"; x: 700; y: 300; width: 80; height: 40 }
            Dialog {
                id: dialog; objectName: "dialog"; modal: true; x: 200; y: 200; width: 300; height: 200
                Button { objectName: "yes"; x: 10; y: 10; width: 100; height: 40 }
                Button { objectName: "no"; x: 150; y: 10; width: 100; height: 40 }
            }
        )"));
        item("page")->forceActiveFocus();
        press(Action::Activate);
        QCOMPARE(item("page")->property("clicks").toInt(), 1);
        auto *popup = m_window->findChild<QObject *>(QStringLiteral("dialog"));
        QTRY_VERIFY(popup->property("opened").toBool());
        press(Action::Right);
        press(Action::Right);
        press(Action::Right);
        const QString inside = focused();
        QVERIFY2(inside == "yes" || inside == "no", qPrintable(inside));
        press(Action::Back);
        QTRY_VERIFY(!popup->property("visible").toBool());
        QTRY_COMPARE(focused(), QStringLiteral("page"));
        QVERIFY(m_root->property("actions").toStringList().isEmpty());
        press(Action::Back);
        QCOMPARE(m_root->property("actions").toStringList(), QStringList{"back"});
    }
    void focusScrollsItselfIntoView()
    {
        QVERIFY(load(R"(
            Flickable {
                objectName: "list"; anchors.fill: parent; contentHeight: 3000; clip: true
                Column {
                    spacing: 200
                    Repeater { model: 10; Button { objectName: "row" + index; width: 300; height: 40 } }
                }
            }
        )"));
        auto *list = item("list");
        QVERIFY(list);
        QVERIFY(item("row0"));
        item("row0")->forceActiveFocus();
        for (int i = 1; i < 8; ++i) {
            press(Action::Down);
            QCOMPARE(focused(), QStringLiteral("row%1").arg(i));
        }
        QVERIFY(list->property("contentY").toDouble() > 0);
        auto *row = item("row7");
        const QRectF rect = row->mapRectToScene(QRectF(0, 0, row->width(), row->height()));
        QVERIFY(rect.bottom() <= m_window->height());
        const double before = list->property("contentY").toDouble();
        m_navigator->scroll(100);
        QCOMPARE(list->property("contentY").toDouble(), before + 100);
        m_navigator->scroll(100000);
        QCOMPARE(list->property("contentY").toDouble(), 3000.0 - list->height());
    }
    void scrollViewsDoNotSwallowDirections()
    {
        // A ScrollView claims arrow keys from controls inside it, which trapped focus.
        QVERIFY(load(R"(
            Button { objectName: "beside"; x: 20; y: 100; width: 80; height: 40 }
            ScrollView {
                x: 200; y: 20; width: 400; height: 300; contentWidth: availableWidth
                Column {
                    spacing: 20
                    Button { objectName: "one"; width: 200; height: 40 }
                    TextField { objectName: "two"; width: 200; height: 40; text: "abc" }
                    Button { objectName: "three"; width: 200; height: 40 }
                }
            }
        )"));
        item("one")->forceActiveFocus();
        press(Action::Down);
        QCOMPARE(focused(), QStringLiteral("two"));
        press(Action::Down);
        QCOMPARE(focused(), QStringLiteral("three"));
        press(Action::Left);
        QCOMPARE(focused(), QStringLiteral("beside"));
    }
    void listsThatHandleKeysLetGoAtTheirEdges()
    {
        QVERIFY(load(R"(
            Button { objectName: "side"; x: 20; y: 200; width: 100; height: 40 }
            FocusScope {
                objectName: "grid"; x: 200; y: 100; width: 300; height: 300; activeFocusOnTab: true
                property int cell: 0
                // As in GridView, active focus passes on to the current item inside.
                Item { focus: true; width: 100; height: 100 }
                Keys.onLeftPressed: event => { if (cell === 0) event.accepted = false; else --cell; }
                Keys.onRightPressed: event => { if (cell === 2) event.accepted = false; else ++cell; }
            }
        )"));
        auto *grid = item("grid");
        grid->forceActiveFocus();
        press(Action::Right);
        press(Action::Right);
        QCOMPARE(grid->property("cell").toInt(), 2);
        QCOMPARE(focused(), QStringLiteral("grid"));
        press(Action::Left);
        press(Action::Left);
        QCOMPARE(grid->property("cell").toInt(), 0);
        QCOMPARE(focused(), QStringLiteral("grid"));
        press(Action::Left);
        QCOMPARE(focused(), QStringLiteral("side"));
    }
    void textFieldsNeverReceiveATypedSpace()
    {
        QVERIFY(load(R"(TextField { objectName: "field"; x: 20; y: 20; width: 200; height: 40 })"));
        item("field")->forceActiveFocus();
        press(Action::Activate);
        QCOMPARE(item("field")->property("text").toString(), QString());
    }
    void contextButtonUsesTheFocusedItemFirst()
    {
        QVERIFY(load(R"(
            Button { objectName: "plain"; x: 20; y: 20; width: 100; height: 40 }
            Button { objectName: "own"; x: 20; y: 100; width: 100; height: 40; property int opens: 0; function gamepadContext() { ++opens; } }
            Item {
                x: 20; y: 200; width: 200; height: 100
                property int opens: 0
                objectName: "holder"
                function gamepadContext() { ++opens; }
                Button { objectName: "inner"; width: 100; height: 40 }
            }
        )"));
        item("own")->forceActiveFocus();
        press(Action::Context);
        QCOMPARE(item("own")->property("opens").toInt(), 1);
        item("inner")->forceActiveFocus();
        press(Action::Context);
        QCOMPARE(item("holder")->property("opens").toInt(), 1);
        item("plain")->forceActiveFocus();
        press(Action::Context);
        QCOMPARE(m_root->property("actions").toStringList(), QStringList{"context"});
    }
    void menusStartAtTheTopAndCloseWithBack()
    {
        QVERIFY(load(R"(
            Button { objectName: "opener"; x: 20; y: 20; width: 100; height: 40; function gamepadContext() { menu.popup(this, 0, height); } }
            Menu {
                id: menu; objectName: "menu"
                property string chosen: ""
                MenuItem { objectName: "first"; text: "First"; onTriggered: menu.chosen = "first" }
                MenuItem { objectName: "second"; text: "Second"; onTriggered: menu.chosen = "second" }
                MenuItem { objectName: "third"; text: "Third"; onTriggered: menu.chosen = "third" }
            }
        )"));
        item("opener")->forceActiveFocus();
        press(Action::Context);
        auto *menu = m_window->findChild<QObject *>(QStringLiteral("menu"));
        QTRY_VERIFY(menu->property("opened").toBool());
        press(Action::Down);
        QCOMPARE(focused(), QStringLiteral("first"));
        press(Action::Down);
        QCOMPARE(focused(), QStringLiteral("second"));
        press(Action::Activate);
        QTRY_VERIFY(!menu->property("visible").toBool());
        QCOMPARE(menu->property("chosen").toString(), QStringLiteral("second"));
        QTRY_COMPARE(focused(), QStringLiteral("opener"));
        press(Action::Context);
        QTRY_VERIFY(menu->property("opened").toBool());
        press(Action::Back);
        QTRY_VERIFY(!menu->property("visible").toBool());
        QCOMPARE(menu->property("chosen").toString(), QStringLiteral("second"));
    }
    void plainItemsCanOfferFocusAndAct()
    {
        QVERIFY(load(R"(
            Rectangle {
                objectName: "row"; x: 20; y: 20; width: 200; height: 50; activeFocusOnTab: true
                property int opens: 0
                Keys.onSpacePressed: ++opens
            }
            Button { objectName: "next"; x: 20; y: 200; width: 100; height: 40 }
        )"));
        item("next")->forceActiveFocus();
        press(Action::Up);
        QCOMPARE(focused(), QStringLiteral("row"));
        press(Action::Activate);
        QCOMPARE(item("row")->property("opens").toInt(), 1);
    }
    void pageButtonsWaitWhileADialogOrMenuIsOpen()
    {
        QVERIFY(load(R"(
            Button { objectName: "opener"; x: 20; y: 20; width: 100; height: 40; property int opens: 0; function gamepadContext() { ++opens; menu.popup(this, 0, height); } }
            Menu { id: menu; objectName: "menu"; MenuItem { objectName: "first"; text: "First" } }
        )"));
        item("opener")->forceActiveFocus();
        press(Action::Context);
        auto *menu = m_window->findChild<QObject *>(QStringLiteral("menu"));
        QTRY_VERIFY(menu->property("opened").toBool());
        // Focus is still outside the menu here, which is when the page's action used to run too.
        for (const Action action : {Action::Context, Action::Menu, Action::Details, Action::NextPage, Action::PreviousPage}) press(action);
        QVERIFY(m_root->property("actions").toStringList().isEmpty());
        QCOMPARE(item("opener")->property("opens").toInt(), 1);
        QVERIFY(menu->property("visible").toBool());
        press(Action::Down);
        QCOMPARE(focused(), QStringLiteral("first"));
        for (const Action action : {Action::Context, Action::Menu, Action::Details, Action::NextPage, Action::PreviousPage}) press(action);
        QVERIFY(m_root->property("actions").toStringList().isEmpty());
        press(Action::Back);
        QTRY_VERIFY(!menu->property("visible").toBool());
        // Closed again, the same buttons work.
        press(Action::NextPage);
        QCOMPARE(m_root->property("actions").toStringList(), QStringList{"nextPage"});
    }
    void pageButtonsReachTheWindow()
    {
        QVERIFY(load(""));
        press(Action::Menu);
        press(Action::Details);
        press(Action::NextPage);
        press(Action::PreviousPage);
        QCOMPARE(m_root->property("actions").toStringList(), QStringList({"menu", "details", "nextPage", "previousPage"}));
    }
};

int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    QQuickStyle::setStyle("Basic");
    GamepadNavigationTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "gamepadnavigationtest.moc"
