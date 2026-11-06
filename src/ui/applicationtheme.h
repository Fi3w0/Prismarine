#pragma once
#include <QObject>
#include <QPalette>
#include <QColor>
#include <QVariantMap>

class AppPreferences;

// Keeps Qt's standard controls/dialogs in step with the QML theme.
class ApplicationTheme final : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool systemLight READ systemLight NOTIFY systemPaletteChanged)
public:
    explicit ApplicationTheme(AppPreferences &preferences);
    ~ApplicationTheme() override;
    bool systemLight() const { return m_systemPalette.color(QPalette::Window).lightnessF() > 0.5; }
signals:
    void systemPaletteChanged();
protected:
    bool eventFilter(QObject *object, QEvent *event) override;
private:
    void apply();
    AppPreferences &m_preferences;
    QPalette m_systemPalette;
    QString m_theme;
    QColor m_accent;
    QVariantMap m_overrides;
    bool m_applying = false;
    int m_systemWheelLines = 3;
};
