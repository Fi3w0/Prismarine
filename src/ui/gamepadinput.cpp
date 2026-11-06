#include "gamepadinput.h"
#include <QGuiApplication>
#ifdef PRISMARINE_HAS_SDL
#define SDL_MAIN_HANDLED
#include <SDL.h>
#endif

GamepadInput::GamepadInput(QObject *parent) : QObject(parent)
{
#ifdef PRISMARINE_HAS_SDL
    SDL_SetMainReady();
    SDL_SetHint(SDL_HINT_NO_SIGNAL_HANDLERS, "1");
    // SDL has no window of its own here; the application state below decides when input counts.
    SDL_SetHint(SDL_HINT_JOYSTICK_ALLOW_BACKGROUND_EVENTS, "1");
    m_initialized = SDL_Init(SDL_INIT_GAMECONTROLLER) == 0;
    if (!m_initialized) { qWarning() << "Controller support is off:" << SDL_GetError(); return; }
    m_clock.start();
    connect(&m_timer, &QTimer::timeout, this, &GamepadInput::poll);
    connect(qApp, &QGuiApplication::applicationStateChanged, this, [this](Qt::ApplicationState state) {
        if (state != Qt::ApplicationActive) m_state.reset();
        updateRate();
    });
    openFirst();
    updateRate();
#endif
}

GamepadInput::~GamepadInput()
{
#ifdef PRISMARINE_HAS_SDL
    close();
    if (m_initialized) SDL_Quit();
#endif
}

bool GamepadInput::available() const
{
    return m_initialized;
}

void GamepadInput::setEnabled(bool enabled)
{
    if (m_enabled == enabled) return;
    m_enabled = enabled;
    m_state.reset();
    updateRate();
    emit enabledChanged();
}

void GamepadInput::updateRate()
{
#ifdef PRISMARINE_HAS_SDL
    if (!m_initialized) return;
    const bool reading = m_enabled && m_controller && qApp->applicationState() == Qt::ApplicationActive;
    // Fast only while it matters; otherwise just notice a controller being plugged in.
    m_timer.setInterval(reading ? 16 : 1000);
    if (!m_timer.isActive()) m_timer.start();
#endif
}

void GamepadInput::close()
{
#ifdef PRISMARINE_HAS_SDL
    if (m_controller) SDL_GameControllerClose(static_cast<SDL_GameController *>(m_controller));
    m_controller = nullptr;
    m_instanceId = -1;
    m_deviceName.clear();
    m_state.reset();
#endif
}

void GamepadInput::openFirst()
{
#ifdef PRISMARINE_HAS_SDL
    for (int i = 0; i < SDL_NumJoysticks() && !m_controller; ++i) {
        if (!SDL_IsGameController(i)) continue;
        auto *controller = SDL_GameControllerOpen(i);
        if (!controller) continue;
        m_controller = controller;
        m_instanceId = SDL_JoystickInstanceID(SDL_GameControllerGetJoystick(controller));
        m_deviceName = QString::fromUtf8(SDL_GameControllerName(controller));
        const SDL_GameControllerType type = SDL_GameControllerGetType(controller);
        m_playStationLabels = type == SDL_CONTROLLER_TYPE_PS3 || type == SDL_CONTROLLER_TYPE_PS4 || type == SDL_CONTROLLER_TYPE_PS5;
    }
    emit connectionChanged();
#endif
}

void GamepadInput::poll()
{
#ifdef PRISMARINE_HAS_SDL
    SDL_Event event;
    bool devicesChanged = false, removed = false;
    while (SDL_PollEvent(&event)) {
        if (event.type == SDL_CONTROLLERDEVICEADDED) devicesChanged = true;
        if (event.type == SDL_CONTROLLERDEVICEREMOVED && event.cdevice.which == m_instanceId) removed = true;
    }
    if (removed) { close(); devicesChanged = true; }
    if (devicesChanged && !m_controller) { openFirst(); updateRate(); }
    const qint64 now = m_clock.elapsed();
    const double seconds = qMin(qint64(100), now - m_lastPollMs) / 1000.0;
    m_lastPollMs = now;
    if (!m_controller || !m_enabled || qApp->applicationState() != Qt::ApplicationActive) return;
    auto *controller = static_cast<SDL_GameController *>(m_controller);
    using Button = GamepadState::Button;
    static const struct { Button button; SDL_GameControllerButton sdl; } buttons[] = {
        {Button::South, SDL_CONTROLLER_BUTTON_A}, {Button::East, SDL_CONTROLLER_BUTTON_B}, {Button::North, SDL_CONTROLLER_BUTTON_Y}, {Button::West, SDL_CONTROLLER_BUTTON_X},
        {Button::Start, SDL_CONTROLLER_BUTTON_START}, {Button::LeftShoulder, SDL_CONTROLLER_BUTTON_LEFTSHOULDER}, {Button::RightShoulder, SDL_CONTROLLER_BUTTON_RIGHTSHOULDER},
        {Button::DpadUp, SDL_CONTROLLER_BUTTON_DPAD_UP}, {Button::DpadDown, SDL_CONTROLLER_BUTTON_DPAD_DOWN}, {Button::DpadLeft, SDL_CONTROLLER_BUTTON_DPAD_LEFT}, {Button::DpadRight, SDL_CONTROLLER_BUTTON_DPAD_RIGHT},
    };
    for (const auto &entry : buttons) m_state.setButton(entry.button, SDL_GameControllerGetButton(controller, entry.sdl));
    const auto axis = [&](SDL_GameControllerAxis which) { return SDL_GameControllerGetAxis(controller, which) / 32767.0; };
    m_state.setLeftStick(axis(SDL_CONTROLLER_AXIS_LEFTX), axis(SDL_CONTROLLER_AXIS_LEFTY));
    m_state.setRightStickY(axis(SDL_CONTROLLER_AXIS_RIGHTY));
    const auto actions = m_state.update(now);
    for (const auto item : actions) emit action(item);
    if (const double speed = m_state.scrollVelocity(); speed != 0) emit scrollBy(speed * seconds);
#endif
}
