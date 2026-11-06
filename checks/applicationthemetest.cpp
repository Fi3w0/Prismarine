#include <QtTest>
#include <QGuiApplication>
#include <QStyleHints>
#include <QTemporaryDir>
#include "core/preferences/apppreferences.h"
#include "ui/applicationtheme.h"
#ifdef PRISMARINE_HAS_WIDGETS
#include <QApplication>
#include <QFileDialog>
#endif

class ApplicationThemeTest : public QObject {
    Q_OBJECT
private slots:
    void scrollSpeedMultipliesTheSystemSetting()
    {
        auto *hints = QGuiApplication::styleHints();
        const int system = hints->wheelScrollLines();
        QTemporaryDir dir;
        {
            AppPreferences preferences(dir.path() + "/prefs.ini");
            ApplicationTheme theme(preferences);
            QCOMPARE(preferences.scrollSpeed(), 2);
            QCOMPARE(hints->wheelScrollLines(), system * 2);
            preferences.setScrollSpeed(3);
            QCOMPARE(hints->wheelScrollLines(), system * 3);
            preferences.setScrollSpeed(9);
            QCOMPARE(preferences.scrollSpeed(), 3);
            preferences.setScrollSpeed(1);
            QCOMPARE(hints->wheelScrollLines(), system);
            preferences.setScrollSpeed(3);
            AppPreferences reloaded(dir.path() + "/prefs.ini");
            QCOMPARE(reloaded.scrollSpeed(), 3);
        }
        QCOMPARE(hints->wheelScrollLines(), system);
    }
    void systemModeTracksPaletteChanges()
    {
        const QPalette original = QGuiApplication::palette();
        QTemporaryDir root;
        AppPreferences preferences(root.path() + "/prefs.ini"); preferences.setTheme("system");
        ApplicationTheme theme(preferences);
        QPalette desktop = original;
        desktop.setColor(QPalette::Window, QColor("#dce5ef"));
#ifdef PRISMARINE_HAS_WIDGETS
        QApplication::setPalette(desktop);
#else
        QGuiApplication::setPalette(desktop);
#endif
        QCoreApplication::processEvents();
        preferences.setTheme("deep");
        QCOMPARE(QGuiApplication::palette().color(QPalette::Window), QColor("#142331"));
        preferences.setTheme("system");
        QCOMPARE(QGuiApplication::palette().color(QPalette::Window), QColor("#dce5ef"));
#ifdef PRISMARINE_HAS_WIDGETS
        QApplication::setPalette(original);
#else
        QGuiApplication::setPalette(original);
#endif
        QCoreApplication::processEvents();
    }
    void paletteOverridesReachNativeControls()
    {
        QTemporaryDir root;
        const auto desktop = QGuiApplication::palette();
        AppPreferences preferences(root.filePath("preferences.ini"));
        ApplicationTheme theme(preferences);
        preferences.setPaletteOverrides({{"deep", QVariantMap{{"surface", "#203040"}, {"base", "#111923"}, {"text", "#f1f7ff"}}},
            {"light", QVariantMap{{"surface", "#fff5ee"}, {"base", "#f8efe4"}}}});
        QCOMPARE(QGuiApplication::palette().color(QPalette::Window), QColor("#203040"));
        QCOMPARE(QGuiApplication::palette().color(QPalette::Base), QColor("#111923"));
        QCOMPARE(QGuiApplication::palette().color(QPalette::Text), QColor("#f1f7ff"));
#ifdef PRISMARINE_HAS_WIDGETS
        QFileDialog chooser;
        chooser.setOption(QFileDialog::DontUseNativeDialog);
        QCOMPARE(chooser.palette().color(QPalette::Window), QColor("#203040"));
#endif
        preferences.setTheme("light"); QCoreApplication::processEvents();
        QCOMPARE(QGuiApplication::palette().color(QPalette::Window), QColor("#fff5ee"));
        QCOMPARE(QGuiApplication::palette().color(QPalette::Base), QColor("#f8efe4"));
#ifdef PRISMARINE_HAS_WIDGETS
        QCOMPARE(chooser.palette().color(QPalette::Window), QColor("#fff5ee"));
#endif
        preferences.setTheme("system");
        QCOMPARE(QGuiApplication::palette().color(QPalette::Window), theme.systemLight() ? QColor("#fff5ee") : QColor("#203040"));
        preferences.setPaletteOverrides({});
        QCOMPARE(QGuiApplication::palette().color(QPalette::Window), desktop.color(QPalette::Window));
        preferences.setTheme("deep"); preferences.setAccentColor(QColor("#583dc3"));
        QCOMPARE(QGuiApplication::palette().color(QPalette::HighlightedText), QColor(Qt::white));
    }
    void followsPreferencesAndRestoresSystem()
    {
        const QPalette system = QGuiApplication::palette();
        QTemporaryDir root;
        AppPreferences preferences(root.path() + "/prefs.ini");
        ApplicationTheme theme(preferences);
        QCOMPARE(QGuiApplication::palette().color(QPalette::Window), QColor("#142331"));
        QVERIFY(QGuiApplication::palette().color(QPalette::Text).lightness() > 128);
#ifdef PRISMARINE_HAS_WIDGETS
        QFileDialog chooser(nullptr, "Theme check", root.path());
        chooser.setOption(QFileDialog::DontUseNativeDialog);
        QCOMPARE(chooser.palette().color(QPalette::Window), QColor("#142331"));
#endif
        preferences.setTheme("light");
        QCoreApplication::processEvents();
        QCOMPARE(QGuiApplication::palette().color(QPalette::Window), QColor("#f8faf8"));
        QVERIFY(QGuiApplication::palette().color(QPalette::Text).lightness() < 128);
#ifdef PRISMARINE_HAS_WIDGETS
        QCOMPARE(chooser.palette().color(QPalette::Window), QColor("#f8faf8"));
#endif
        preferences.setTheme("deep");
        preferences.setAccentColor(QColor("#b892f2"));
        QCOMPARE(QGuiApplication::palette().color(QPalette::Highlight), QColor("#b892f2"));
        preferences.setTheme("system");
        QCOMPARE(QGuiApplication::palette().color(QPalette::Window), system.color(QPalette::Window));
    }
};

int main(int argc, char **argv)
{
#ifdef PRISMARINE_HAS_WIDGETS
    QApplication app(argc, argv);
#else
    QGuiApplication app(argc, argv);
#endif
    ApplicationThemeTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "applicationthemetest.moc"
