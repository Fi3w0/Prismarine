#pragma once
#include <QObject>
#include <QStringList>
#include <QVariantList>

// Which backend Prismarine runs on, and what that backend can do.
// Stable uses an installed Prism Launcher. Full uses Prismarine's own Prism-based
// engine, found beside the executable, which reports what it supports.
class LauncherMode : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString mode READ mode NOTIFY changed)
    Q_PROPERTY(bool fullAvailable READ fullAvailable NOTIFY changed)
    Q_PROPERTY(QString prismProgram READ prismProgram NOTIFY changed)
    Q_PROPERTY(QVariantList fullFeatures READ fullFeatures NOTIFY changed)
    Q_PROPERTY(QString interfaceMode READ interfaceMode WRITE setInterfaceMode NOTIFY interfaceModeChanged)
public:
    static constexpr int EngineProtocol = 1;
    explicit LauncherMode(const QString &engineDir = {}, const QString &interfaceMode = QStringLiteral("desktop"), QObject *parent = nullptr);
    static bool validInterface(const QString &value);
    QString mode() const { return fullAvailable() ? QStringLiteral("full") : QStringLiteral("stable"); }
    bool fullAvailable() const { return m_engineValid; }
    QString prismProgram() const { return m_prismProgram; }
    QVariantList fullFeatures() const;
    QString interfaceMode() const { return m_interfaceMode; }
    void setInterfaceMode(const QString &value);
    Q_INVOKABLE bool supports(const QString &feature) const { return m_capabilities.contains(feature); }
    // Looks for the engine and Prism again. Starts the engine only when its file exists.
    Q_INVOKABLE void refresh();
signals:
    void changed();
    void interfaceModeChanged();
private:
    QString m_engineDir, m_prismProgram, m_interfaceMode;
    QStringList m_capabilities;
    bool m_engineValid = false;
};
