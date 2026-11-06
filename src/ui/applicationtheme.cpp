#include "applicationtheme.h"
#include "core/preferences/apppreferences.h"
#include <QGuiApplication>
#include <QStyleHints>
#include <QScopedValueRollback>
#include <QEvent>
#include <cmath>
#ifdef PRISMARINE_HAS_WIDGETS
#include <QApplication>
#endif

namespace {
void setPalette(const QPalette &palette)
{
#ifdef PRISMARINE_HAS_WIDGETS
    QApplication::setPalette(palette);
#else
    QGuiApplication::setPalette(palette);
#endif
}
void requestScheme(const QString &theme)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 8, 0)
    QGuiApplication::styleHints()->setColorScheme(theme == "deep" ? Qt::ColorScheme::Dark
        : theme == "light" ? Qt::ColorScheme::Light : Qt::ColorScheme::Unknown);
#else
    Q_UNUSED(theme)
#endif
}
QPalette themedPalette(QPalette palette, bool light, QColor accent, const QVariantMap &overrides)
{
    const auto colour = [&](const QString &role, const char *dark, const char *day) {
        return QColor(overrides.value(role, QString::fromLatin1(light ? day : dark)).toString());
    };
    const QColor text = colour("text", "#e8f1f2", "#14232b");
    const QColor muted = colour("subtext", "#93a8b3", "#55697a");
    const QColor surface = colour("surface", "#142331", "#f8faf8");
    const QColor base = colour("base", "#0d1822", "#eef1ee");
    const QColor button = colour("surfaceHi", "#1a2d3d", "#e2ebe8");
    const QColor outline = colour("outline", "#64808f", "#6a7d79");
    if (light) accent = accent.darker(200);
    palette.setColor(QPalette::Window, surface);
    palette.setColor(QPalette::Base, base);
    palette.setColor(QPalette::AlternateBase, colour("rowAlt", "#182a39", "#eef3f1"));
    palette.setColor(QPalette::Button, button);
    palette.setColor(QPalette::WindowText, text);
    palette.setColor(QPalette::Text, text);
    palette.setColor(QPalette::ButtonText, text);
    palette.setColor(QPalette::PlaceholderText, muted);
    palette.setColor(QPalette::ToolTipBase, surface);
    palette.setColor(QPalette::ToolTipText, text);
    palette.setColor(QPalette::BrightText, colour("bone", "#f3ead6", "#1b3a36"));
    palette.setColor(QPalette::Highlight, accent);
    const auto luminance = [](const QColor &c) {
        const auto linear = [](double v) { return v <= 0.04045 ? v / 12.92 : std::pow((v + 0.055) / 1.055, 2.4); };
        return 0.2126 * linear(c.redF()) + 0.7152 * linear(c.greenF()) + 0.0722 * linear(c.blueF());
    };
    const double value = luminance(accent), dark = luminance(QColor("#06211d"));
    const QColor automaticInk = (qMax(value, dark) + 0.05) / (qMin(value, dark) + 0.05) >= 4.5 ? QColor("#06211d")
        : 1.05 / (value + 0.05) >= 4.5 ? QColor("#ffffff") : QColor("#000000");
    palette.setColor(QPalette::HighlightedText, overrides.contains("accentInk") ? QColor(overrides.value("accentInk").toString()) : automaticInk);
    palette.setColor(QPalette::Link, accent);
    palette.setColor(QPalette::LinkVisited, muted);
    palette.setColor(QPalette::Light, outline);
    palette.setColor(QPalette::Midlight, button);
    palette.setColor(QPalette::Mid, outline);
    palette.setColor(QPalette::Dark, colour("border", "#263b4d", "#c9d6d2"));
    palette.setColor(QPalette::Shadow, colour("rail", "#070f17", "#e3e9e6"));
    for (const auto role : {QPalette::WindowText, QPalette::Text, QPalette::ButtonText, QPalette::HighlightedText})
        palette.setColor(QPalette::Disabled, role, muted);
    return palette;
}
}

ApplicationTheme::ApplicationTheme(AppPreferences &preferences)
    : QObject(&preferences), m_preferences(preferences), m_systemPalette(QGuiApplication::palette())
{
    m_systemWheelLines = QGuiApplication::styleHints()->wheelScrollLines();
    connect(&preferences, &AppPreferences::changed, this, [this] { apply(); });
    qGuiApp->installEventFilter(this);
    apply();
}

bool ApplicationTheme::eventFilter(QObject *object, QEvent *event)
{
    if (object == qGuiApp && event->type() == QEvent::ApplicationPaletteChange && !m_applying) {
        const bool wasLight = systemLight();
        m_systemPalette = QGuiApplication::palette();
        if (wasLight != systemLight()) emit systemPaletteChanged();
        m_theme.clear(); apply();
    }
    return QObject::eventFilter(object, event);
}

ApplicationTheme::~ApplicationTheme()
{
    QGuiApplication::styleHints()->setWheelScrollLines(m_systemWheelLines);
    m_applying = true;
    requestScheme("system");
    setPalette(m_systemPalette);
}

void ApplicationTheme::apply()
{
    // Qt Quick scrolls this many lines of 24 px per wheel notch.
    QGuiApplication::styleHints()->setWheelScrollLines(m_systemWheelLines * m_preferences.scrollSpeed());
    const QString theme = m_preferences.theme();
    const QColor accent = m_preferences.accentColor();
    const auto overrides = m_preferences.paletteOverrides();
    if (m_theme == theme && m_accent == accent && m_overrides == overrides) return;
    const QScopedValueRollback<bool> guard(m_applying, true);
    m_theme = theme;
    m_accent = accent;
    m_overrides = overrides;
    requestScheme(theme);
    const bool light = theme == "light" || (theme == "system" && systemLight());
    const auto colours = overrides.value(light ? "light" : "deep").toMap();
    setPalette(theme == "system" && colours.isEmpty() ? m_systemPalette : themedPalette(m_systemPalette, light, accent, colours));
}
