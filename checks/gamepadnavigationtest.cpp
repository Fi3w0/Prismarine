#include "gamepadfixture.h"
#include "ui/spatialfocus.h"
#include <QGuiApplication>
#include <QQuickStyle>

// Moving focus, dialogs, menus and scrolling, in a real window with simulated input.
class GamepadNavigationTest : public GamepadWindowFixture {
    Q_OBJECT
private slots:
    void cleanup() { closeWindow(); }


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
