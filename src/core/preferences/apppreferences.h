#pragma once
#include <QObject>
#include <QColor>
#include <QSettings>
#include <QVariantMap>
#include <QUrl>

class AppPreferences : public QObject {
    Q_OBJECT
    Q_PROPERTY(int sidebarWidth READ sidebarWidth WRITE setSidebarWidth NOTIFY sidebarWidthChanged)
    Q_PROPERTY(QString libraryView READ libraryView WRITE setLibraryView NOTIFY changed)
    Q_PROPERTY(QString sortOrder READ sortOrder WRITE setSortOrder NOTIFY changed)
    Q_PROPERTY(QString startPage READ startPage WRITE setStartPage NOTIFY changed)
    Q_PROPERTY(bool showScreenshots READ showScreenshots WRITE setShowScreenshots NOTIFY changed)
    Q_PROPERTY(bool animations READ animations WRITE setAnimations NOTIFY changed)
    Q_PROPERTY(bool decoFrames READ decoFrames WRITE setDecoFrames NOTIFY changed)
    Q_PROPERTY(bool firstRunSeen READ firstRunSeen WRITE setFirstRunSeen NOTIFY changed)
    Q_PROPERTY(QColor accentColor READ accentColor WRITE setAccentColor NOTIFY changed)
    Q_PROPERTY(QString theme READ theme WRITE setTheme NOTIFY changed)
    Q_PROPERTY(QStringList favorites READ favorites NOTIFY favoritesChanged)
    Q_PROPERTY(QVariantMap notes READ notes NOTIFY notesChanged)
    Q_PROPERTY(QVariantMap covers READ covers NOTIFY coversChanged)
    // {instanceId: {card: {mode, url}, hero: {mode, url}}}; see setArtwork.
    Q_PROPERTY(QVariantMap artwork READ artwork NOTIFY coversChanged)
    // Experimental: launch copies of an instance with other accounts (see AltLaunch).
    Q_PROPERTY(bool multiAccount READ multiAccount WRITE setMultiAccount NOTIFY changed)
    // [{instanceId, name, address}] shown on Home with live status.
    Q_PROPERTY(QVariantList serverFavorites READ serverFavorites NOTIFY serverFavoritesChanged)
    Q_PROPERTY(QString fileName READ fileName CONSTANT)
    // What Prismarine's window does while a game runs: keep, minimize or hide.
    Q_PROPERTY(QString whilePlaying READ whilePlaying WRITE setWhilePlaying NOTIFY changed)
    // Whether Prism may open its console window; off by default.
    Q_PROPERTY(bool prismConsole READ prismConsole WRITE setPrismConsole NOTIFY changed)
    // Path of the Prism program to launch with; empty picks it automatically.
    Q_PROPERTY(QString prismProgram READ prismProgram WRITE setPrismProgram NOTIFY changed)
    // Per-instance overrides of whilePlaying; "" or absent uses the global choice.
    Q_PROPERTY(QVariantMap instanceWhilePlaying READ instanceWhilePlaying NOTIFY changed)
public:
    explicit AppPreferences(const QString &file = {}, QObject *parent = nullptr);
    int sidebarWidth() const;
    void setSidebarWidth(int value);
    QString libraryView() const;
    QString sortOrder() const;
    QString startPage() const;
    bool showScreenshots() const;
    bool animations() const;
    bool decoFrames() const;
    bool firstRunSeen() const;
    QColor accentColor() const;
    QString theme() const;
    QStringList favorites() const;
    QVariantMap notes() const;
    QVariantMap covers() const;
    QString fileName() const { return m_settings.fileName(); }
    QString prismProgram() const;
    void setPrismProgram(const QString &value);
    Q_INVOKABLE void setPrismProgramFromUrl(const QUrl &url);
    bool prismConsole() const;
    void setPrismConsole(bool value);
    QString whilePlaying() const;
    void setWhilePlaying(const QString &value);
    QVariantMap instanceWhilePlaying() const;
    Q_INVOKABLE void setInstanceWhilePlaying(const QString &id, const QString &value);
    // The effective choice for one instance.
    Q_INVOKABLE QString whilePlayingFor(const QString &id) const;
    bool multiAccount() const;
    void setMultiAccount(bool value);
    QVariantList serverFavorites() const;
    Q_INVOKABLE bool isServerFavorite(const QString &instanceId, const QString &address) const;
    Q_INVOKABLE void toggleServerFavorite(const QString &instanceId, const QString &name, const QString &address);
    void setLibraryView(const QString &value);
    void setSortOrder(const QString &value);
    void setStartPage(const QString &value);
    void setShowScreenshots(bool value);
    void setAnimations(bool value);
    void setDecoFrames(bool value);
    void setFirstRunSeen(bool value);
    void setAccentColor(const QColor &value);
    void setTheme(const QString &value);
    Q_INVOKABLE void toggleFavorite(const QString &id);
    Q_INVOKABLE void setNote(const QString &id, const QString &text);
    QVariantMap artwork() const;
    // slot: card, hero or both. mode: "" (default), art, screenshot, image (needs url).
    Q_INVOKABLE bool setArtwork(const QString &id, const QString &slot, const QString &mode, const QUrl &url = {});
    // Sets the same custom image for card and hero.
    Q_INVOKABLE bool setCover(const QString &id, const QUrl &url);
    Q_INVOKABLE void clearCover(const QString &id);
    Q_INVOKABLE void sync();
signals:
    void sidebarWidthChanged();
    void changed();
    void favoritesChanged();
    void notesChanged();
    void coversChanged();
    void serverFavoritesChanged();
    void errorOccurred(const QString &message);
private:
    void save(const QString &key, const QVariant &value);
    QString coversDir() const;
    QSettings m_settings;
    bool m_hadSettings = false;
};
