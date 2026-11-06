#pragma once
#include "gamepadstate.h"
#include <QElapsedTimer>
#include <QObject>
#include <QTimer>

// Reads the first connected controller through SDL while Prismarine is the active application,
// so a game in front receives the controller alone. Builds without SDL report it as unavailable.
class GamepadInput : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool connected READ connected NOTIFY connectionChanged)
    Q_PROPERTY(QString deviceName READ deviceName NOTIFY connectionChanged)
    Q_PROPERTY(bool enabled READ enabled WRITE setEnabled NOTIFY enabledChanged)
    // What the confirm and cancel buttons are called on this controller.
    Q_PROPERTY(QString confirmLabel READ confirmLabel NOTIFY connectionChanged)
    Q_PROPERTY(QString cancelLabel READ cancelLabel NOTIFY connectionChanged)
public:
    explicit GamepadInput(QObject *parent = nullptr);
    ~GamepadInput() override;
    bool available() const;
    bool connected() const { return m_controller != nullptr; }
    QString deviceName() const { return m_deviceName; }
    bool enabled() const { return m_enabled; }
    void setEnabled(bool enabled);
    QString confirmLabel() const { return m_playStationLabels ? QString(QChar(0x2715)) : QStringLiteral("A"); }
    QString cancelLabel() const { return m_playStationLabels ? QString(QChar(0x25CB)) : QStringLiteral("B"); }
    Q_SLOT void setFastRepeat(bool fast) { m_state.setFastRepeat(fast); }
signals:
    void action(GamepadState::Action action);
    void scrollBy(double pixels);
    void connectionChanged();
    void enabledChanged();
private:
    void poll();
    void updateRate();
    void close();
    void openFirst();
    QTimer m_timer;
    QElapsedTimer m_clock;
    GamepadState m_state;
    void *m_controller = nullptr;
    int m_instanceId = -1;
    QString m_deviceName;
    bool m_enabled = true, m_initialized = false, m_playStationLabels = false;
    qint64 m_lastPollMs = 0;
};
