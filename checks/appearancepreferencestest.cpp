#include <QtTest>
#include <QGuiApplication>
#include <QQuickStyle>
#include <QTemporaryDir>
#include <QSettings>
#include <QQmlEngine>
#include <QQmlComponent>
#include <memory>
#include <QQuickWindow>
#include <QQuickItem>
#include <cmath>
#include "core/preferences/apppreferences.h"

namespace {
QQuickItem *findItem(QQuickItem *root, const QString &name)
{
    if (root->objectName() == name) return root;
    for (auto *child : root->childItems()) if (auto *match = findItem(child, name)) return match;
    return nullptr;
}
}

class AppearancePreferencesTest : public QObject {
    Q_OBJECT
private slots:
    void optionsPersistAndStayBounded()
    {
        QTemporaryDir directory;
        const auto path = directory.filePath("preferences.ini");
        {
            AppPreferences preferences(path);
            QCOMPARE(preferences.interfaceSize(), 100);
            QCOMPARE(preferences.libraryDensity(), "comfortable");
            QCOMPARE(preferences.homeSections().size(), 6);
            preferences.setInterfaceSize(115);
            preferences.setInterfaceSize(500);
            QCOMPARE(preferences.interfaceSize(), 115);
            preferences.setLibraryDensity("compact");
            preferences.setLibraryDensity("unknown");
            preferences.setHomeSections({"news", "recent", "unknown", "news"});
            QCOMPARE(preferences.homeSections(), QStringList({"recent", "news"}));
            preferences.sync();
        }
        AppPreferences reopened(path);
        QCOMPARE(reopened.interfaceSize(), 115);
        QCOMPARE(reopened.libraryDensity(), "compact");
        QCOMPARE(reopened.homeSections(), QStringList({"recent", "news"}));
        reopened.setHomeSections({}); reopened.sync();
        AppPreferences empty(path);
        QVERIFY(empty.homeSections().isEmpty());
        reopened.setInterfaceSize(90); reopened.sync();
        QCOMPARE(empty.interfaceSize(), 90);
        AppPreferences isolated(directory.filePath("another.ini"));
        QCOMPARE(isolated.interfaceSize(), 100);
        QCOMPARE(isolated.homeSections().size(), 6);
    }
    void draftAppliesOnlyOnRequest()
    {
        QTemporaryDir directory;
        const auto path = directory.filePath("preferences.ini");
        AppPreferences preferences(path);
        preferences.setTheme("light"); preferences.sync();
        QQmlEngine engine;
        QSignalSpy warnings(&engine, &QQmlEngine::warnings);
        QQmlComponent component(&engine, QUrl("qrc:/appearance/SettingsDraft.qml"));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> draft(component.createWithInitialProperties({{"preferences", QVariant::fromValue(&preferences)}}));
        QVERIFY(draft); QVERIFY(!draft->property("dirty").toBool());
        draft->setProperty("theme", "deep"); draft->setProperty("accentColor", QColor("#ab5678"));
        draft->setProperty("coverSize", 280); draft->setProperty("cornerStyle", "angular");
        draft->setProperty("showCoverBadges", false);
        QVERIFY(draft->property("dirty").toBool());
        QCOMPARE(preferences.theme(), "light"); QCOMPARE(preferences.coverSize(), 0);
        AppPreferences unchanged(path); QCOMPARE(unchanged.accentColor(), QColor("#46d1bb"));
        QVERIFY(QMetaObject::invokeMethod(draft.get(), "load"));
        QVERIFY(!draft->property("dirty").toBool()); QCOMPARE(draft->property("theme").toString(), "light");
        draft->setProperty("theme", "deep"); draft->setProperty("accentColor", QColor("#ab5678"));
        draft->setProperty("coverSize", 280); draft->setProperty("cornerStyle", "angular"); draft->setProperty("showCoverBadges", false);
        QVERIFY(QMetaObject::invokeMethod(draft.get(), "apply"));
        QVERIFY(!draft->property("dirty").toBool());
        AppPreferences applied(path);
        QCOMPARE(applied.theme(), "deep"); QCOMPARE(applied.accentColor(), QColor("#ab5678"));
        QCOMPARE(applied.coverSize(), 280); QCOMPARE(applied.cornerStyle(), "angular"); QVERIFY(!applied.showCoverBadges());
        applied.setCoverSize(999); applied.setCornerStyle("unknown");
        QCOMPARE(applied.coverSize(), 280); QCOMPARE(applied.cornerStyle(), "angular");
        QVERIFY(QMetaObject::invokeMethod(draft.get(), "resetDefaults"));
        QCOMPARE(preferences.theme(), "deep"); QCOMPARE(preferences.coverSize(), 280);
        QVERIFY(draft->property("dirty").toBool());
        QVERIFY(warnings.isEmpty());
    }
    void colourOnlyChangeEnablesApply()
    {
        QTemporaryDir directory;
        AppPreferences preferences(directory.filePath("preferences.ini"));
        QQmlEngine engine;
        QQmlComponent component(&engine, QUrl("qrc:/appearance/SettingsDraft.qml"));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> draft(component.createWithInitialProperties({{"preferences", QVariant::fromValue(&preferences)}}));
        QVERIFY(draft); QVERIFY(!draft->property("dirty").toBool());
        draft->setProperty("accentColor", QColor("#2080c0"));
        QCOMPARE(preferences.accentColor(), QColor("#46d1bb"));
        QVERIFY2(draft->property("dirty").toBool(), "Colour selector changed, but Apply remains disabled");
        draft->setProperty("accentColor", preferences.accentColor());
        QVERIFY(!draft->property("dirty").toBool());
    }
    void compiledSelectorEnablesApplyAfterEachEdit()
    {
        QTemporaryDir directory;
        AppPreferences preferences(directory.filePath("preferences.ini"));
        QQmlEngine engine;
        QQmlComponent component(&engine);
        component.loadFromModule("AppearanceChecks", "ColourApplyFixture");
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QQuickWindow> window(qobject_cast<QQuickWindow *>(component.createWithInitialProperties({{"preferences", QVariant::fromValue(&preferences)}})));
        QVERIFY(window); QVERIFY(QTest::qWaitForWindowExposed(window.get()));
        auto *apply = window->findChild<QQuickItem *>("selectorApply"); QVERIFY(apply);
        auto *sv = window->findChild<QQuickItem *>("accentSaturationValue"); QVERIFY(sv);
        auto *draft = window->findChild<QObject *>("selectorDraft"); QVERIFY(draft);
        // Match consecutive human drags without reading the draft between edits.
        for (const char *channel : {"H", "S", "V"}) {
            auto *slider = findItem(window->contentItem(), QString("accentChannel_") + channel); QVERIFY(slider);
            const auto start = slider->mapToScene(QPointF(slider->width() * 0.5, slider->height() / 2)).toPoint();
            const auto end = slider->mapToScene(QPointF(slider->width() * 0.7, slider->height() / 2)).toPoint();
            QTest::mousePress(window.get(), Qt::LeftButton, Qt::NoModifier, start);
            QTest::mouseMove(window.get(), end, 30);
            QTest::mouseRelease(window.get(), Qt::LeftButton, Qt::NoModifier, end);
        }
        const bool enabledAfterDrags = apply->isEnabled();
        const auto colourAfterDrags = draft->property("accentColor").value<QColor>();
        QVERIFY2(colourAfterDrags != preferences.accentColor(), "Consecutive drags did not change the preview colour");
        QVERIFY2(enabledAfterDrags, "Consecutive HSV drags change the preview but leave Apply disabled");
        QVERIFY(QMetaObject::invokeMethod(draft, "load"));
        for (const char *channel : {"H", "S", "V"}) {
            auto *slider = findItem(window->contentItem(), QString("accentChannel_") + channel); QVERIFY(slider);
            const auto before = preferences.accentColor();
            slider->forceActiveFocus(); QTest::keyClick(window.get(), Qt::Key_Right);
            QVERIFY2(draft->property("accentColor").value<QColor>() != before, channel);
            QVERIFY2(apply->isEnabled(), "Moving an HSV slider leaves Apply disabled");
            QVERIFY(QMetaObject::invokeMethod(draft, "load"));
            const auto point = slider->mapToScene(QPointF(slider->width() * 0.25, slider->height() / 2)).toPoint();
            QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, point);
            QVERIFY2(draft->property("accentColor").value<QColor>() != before, channel);
            QVERIFY2(apply->isEnabled(), "Clicking an HSV slider leaves Apply disabled");
            QVERIFY(QMetaObject::invokeMethod(draft, "load"));
        }
        for (int edit = 0; edit < 3; ++edit) {
            QVERIFY(!apply->isEnabled());
            const auto before = preferences.accentColor();
            const auto point = sv->mapToScene(QPointF(sv->width() * (0.2 + edit * 0.2), sv->height() * 0.3)).toPoint();
            QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, point);
            QVERIFY(draft->property("accentColor").value<QColor>() != before);
            QCOMPARE(preferences.accentColor(), before);
            QVERIFY2(apply->isEnabled(), "Changing the colour selector leaves Apply disabled");
            QTest::mouseClick(window.get(), Qt::LeftButton, Qt::NoModifier, apply->mapToScene(QPointF(60, 20)).toPoint());
            QCOMPARE(preferences.accentColor(), draft->property("accentColor").value<QColor>());
        }
    }
    void homeServerFavoritesValidateAndPersist()
    {
        QTemporaryDir directory;
        const auto path = directory.filePath("preferences.ini");
        AppPreferences preferences(path);
        QSignalSpy errors(&preferences, &AppPreferences::errorOccurred);
        QVERIFY(!preferences.addServerFavorite("", "", "play.example.net"));
        QVERIFY(!preferences.addServerFavorite("alpha", "", "play.example.net:0"));
        QVERIFY(!preferences.addServerFavorite("alpha", "", "play.example.net:99999"));
        QVERIFY(!preferences.addServerFavorite("alpha", "", "host;command"));
        QCOMPARE(errors.size(), 4);
        QVERIFY(preferences.addServerFavorite("alpha", "", "  play.example.net:25565  "));
        QVERIFY(preferences.addServerFavorite("alpha", "Duplicate", "PLAY.EXAMPLE.NET:25565"));
        QCOMPARE(preferences.serverFavorites().size(), 1);
        QVERIFY(preferences.addServerFavorite("beta", "Other instance", "play.example.net:25565"));
        QVERIFY(preferences.addServerFavorite("alpha", "IPv6", "[::1]:25566"));
        preferences.sync();
        AppPreferences reopened(path);
        QCOMPARE(reopened.serverFavorites().size(), 3);
        QCOMPARE(reopened.serverFavorites().first().toMap().value("name").toString(), "play.example.net:25565");
        QVERIFY(reopened.isServerFavorite("alpha", "play.example.net:25565"));
        reopened.toggleServerFavorite("alpha", "", "play.example.net:25565");
        QVERIFY(!reopened.isServerFavorite("alpha", "play.example.net:25565"));
    }
    void paletteRolesAreValidatedStagedAndSaved()
    {
        QTemporaryDir directory;
        const auto path = directory.filePath("preferences.ini");
        AppPreferences preferences(path);
        const QVariantMap deep{{"base", "#101b2d"}, {"surface", "#1c2a40"}, {"text", "#edf4ff"}};
        const QVariantMap light{{"base", "#e2edf4"}};
        QQmlEngine engine;
        QQmlComponent component(&engine, QUrl("qrc:/appearance/SettingsDraft.qml"));
        QVERIFY2(component.isReady(), qPrintable(component.errorString()));
        std::unique_ptr<QObject> draft(component.createWithInitialProperties({{"preferences", QVariant::fromValue(&preferences)}}));
        QVERIFY(draft);
        draft->setProperty("paletteOverrides", QVariantMap{{"deep", deep}, {"light", light}});
        QVERIFY(draft->property("dirty").toBool()); QVERIFY(preferences.paletteOverrides().isEmpty());
        QVERIFY(QMetaObject::invokeMethod(draft.get(), "apply")); QVERIFY(!draft->property("dirty").toBool());
        AppPreferences reopened(path);
        QCOMPARE(reopened.paletteOverrides().value("deep").toMap(), deep);
        QCOMPARE(reopened.paletteOverrides().value("light").toMap(), light);
        QSignalSpy errors(&preferences, &AppPreferences::errorOccurred);
        preferences.setPaletteOverrides({{"deep", QVariantMap{{"base", "not-a-colour"}}}});
        preferences.setPaletteOverrides({{"deep", QVariantMap{{"base", "transparent"}}}});
        preferences.setPaletteOverrides({{"deep", QVariantMap{{"unknown", "#112233"}}}});
        preferences.setPaletteOverrides({{"unknown-theme", deep}});
        QCOMPARE(errors.size(), 4); QCOMPARE(preferences.paletteOverrides().value("deep").toMap(), deep);
        QQmlComponent paletteComponent(&engine);
        paletteComponent.loadFromModule("AppearanceChecks", "ColorPalette");
        QVERIFY2(paletteComponent.isReady(), qPrintable(paletteComponent.errorString()));
        std::unique_ptr<QObject> palette(paletteComponent.createWithInitialProperties({{"theme", "deep"}, {"overrides", preferences.paletteOverrides()}}));
        QVERIFY(palette); QCOMPARE(palette->property("base").value<QColor>(), QColor("#101b2d"));
        palette->setProperty("theme", "light"); QCOMPARE(palette->property("base").value<QColor>(), QColor("#e2edf4"));
        palette->setProperty("theme", "system"); palette->setProperty("systemMode", 1);
        QCOMPARE(palette->property("base").value<QColor>(), QColor("#e2edf4"));
        palette->setProperty("systemMode", 2); QCOMPARE(palette->property("base").value<QColor>(), QColor("#101b2d"));
        palette->setProperty("theme", "deep"); palette->setProperty("overrides", QVariantMap{});
        palette->setProperty("userAccent", QColor("#583dc3")); QCOMPARE(palette->property("accentInk").value<QColor>(), QColor(Qt::white));
        palette->setProperty("overrides", QVariantMap{{"deep", QVariantMap{{"accentInk", "#ffeedd"}}}});
        QCOMPARE(palette->property("accentInk").value<QColor>(), QColor("#ffeedd"));
        QVERIFY(QMetaObject::invokeMethod(draft.get(), "resetDefaults"));
        QVERIFY(!preferences.paletteOverrides().isEmpty()); QVERIFY(draft->property("dirty").toBool());
        QVERIFY(QMetaObject::invokeMethod(draft.get(), "apply")); QVERIFY(preferences.paletteOverrides().isEmpty());
    }
    void startingPalettesKeepTextAndOutlinesReadable()
    {
        QTemporaryDir directory; AppPreferences preferences(directory.filePath("preferences.ini"));
        QQmlEngine engine;
        QQmlComponent draftComponent(&engine, QUrl("qrc:/appearance/SettingsDraft.qml"));
        std::unique_ptr<QObject> draft(draftComponent.createWithInitialProperties({{"preferences", QVariant::fromValue(&preferences)}})); QVERIFY(draft);
        QQmlComponent paletteComponent(&engine); paletteComponent.loadFromModule("AppearanceChecks", "ColorPalette");
        std::unique_ptr<QObject> palette(paletteComponent.create()); QVERIFY(palette);
        QQmlComponent cardsComponent(&engine); cardsComponent.loadFromModule("AppearanceChecks", "PaletteStartingPoints");
        QVERIFY2(cardsComponent.isReady(), qPrintable(cardsComponent.errorString()));
        std::unique_ptr<QQuickItem> cards(qobject_cast<QQuickItem *>(cardsComponent.createWithInitialProperties({{"preferences", QVariant::fromValue(draft.get())}, {"previewColors", QVariant::fromValue(palette.get())}})));
        QVERIFY(cards); cards->setWidth(840);
        const auto luminance = [](const QColor &c) {
            const auto linear = [](double v) { return v <= .04045 ? v / 12.92 : std::pow((v + .055) / 1.055, 2.4); };
            return .2126 * linear(c.redF()) + .7152 * linear(c.greenF()) + .0722 * linear(c.blueF());
        };
        const auto contrast = [&](const QColor &a, const QColor &b) { const auto x = luminance(a), y = luminance(b); return (qMax(x, y) + .05) / (qMin(x, y) + .05); };
        for (const char *theme : {"deep", "light"}) {
            palette->setProperty("theme", theme);
            for (const char *name : {"default", "midnight", "glass", "slate"}) {
                auto *button = findItem(cards.get(), QString("paletteStart_") + name); QVERIFY(button);
                QVERIFY(QMetaObject::invokeMethod(button, "clicked")); palette->setProperty("overrides", draft->property("paletteOverrides"));
                for (const char *role : {"rail", "base", "mantle", "surface", "surfaceHi", "rowAlt", "inset"}) {
                    const auto bg = palette->property(role).value<QColor>();
                    const auto context = QByteArray(theme) + "/" + name + "/" + role;
                    QVERIFY2(contrast(palette->property("text").value<QColor>(), bg) >= 4.5, context.constData());
                    QVERIFY2(contrast(palette->property("subtext").value<QColor>(), bg) >= 4.5, context.constData());
                    QVERIFY2(contrast(palette->property("outline").value<QColor>(), bg) >= 3, context.constData());
                }
            }
        }
        QVERIFY(preferences.paletteOverrides().isEmpty());
    }
    void invalidStoredSizesFallBack()
    {
        QTemporaryDir directory;
        const auto path = directory.filePath("preferences.ini");
        {
            QSettings file(path, QSettings::IniFormat);
            file.setValue("interface/size", -100);
            file.setValue("library/density", "unknown");
            file.setValue("home/sections", QStringList({"worlds", "unknown"}));
        }
        AppPreferences preferences(path);
        QCOMPARE(preferences.interfaceSize(), 100);
        QCOMPARE(preferences.libraryDensity(), "comfortable");
        QCOMPARE(preferences.homeSections(), QStringList({"worlds"}));
    }
};
int main(int argc, char **argv)
{
    QGuiApplication app(argc, argv);
    // The same style as the app. The native macOS style cannot draw these customised controls.
    QQuickStyle::setStyle("Basic");
    AppearancePreferencesTest test;
    return QTest::qExec(&test, argc, argv);
}
#include "appearancepreferencestest.moc"
