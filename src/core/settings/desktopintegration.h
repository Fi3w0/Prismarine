#pragma once
#include <QObject>
#include <QStringList>

// Optional KDE Plasma integration: one KWin window rule that keeps Prism's
// "Please wait…" sign-in/progress window minimized and out of the taskbar while
// Prismarine shows its own launch screen. Prism has no setting for this.
// Only Prismarine's own rule is added or removed; other rules stay untouched.
class DesktopIntegration : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool kdeAvailable READ kdeAvailable CONSTANT)
    Q_PROPERTY(bool hidePrismProgress READ hidePrismProgress NOTIFY changed)
public:
    // `rulesFile` is a KConfig file name or absolute path; tests pass a temporary file.
    explicit DesktopIntegration(QObject *parent = nullptr, const QString &rulesFile = "kwinrulesrc", bool reloadKWin = true);
    bool kdeAvailable() const;
    bool hidePrismProgress() const;
    Q_INVOKABLE bool setHidePrismProgress(bool enabled);
    static constexpr const char *RuleId = "prismarine-hide-prism-progress";
signals:
    void changed();
    void errorOccurred(const QString &message);
private:
    QString read(const QString &group, const QString &key) const;
    bool write(const QString &group, const QString &key, const QString &value) const;
    bool remove(const QString &group, const QString &key) const;
    QStringList ruleIds() const;
    QString m_file;
    bool m_reload;
};
