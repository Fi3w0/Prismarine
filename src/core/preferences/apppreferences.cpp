#include "apppreferences.h"
#include "../servers/serverlist.h"
#include <QRegularExpression>
#include <QCryptographicHash>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QImageReader>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QSaveFile>
#include <QStandardPaths>
#include <QUrl>

AppPreferences::AppPreferences(const QString &file, QObject *parent)
    : QObject(parent), m_settings(file.isEmpty()
          ? QStandardPaths::writableLocation(QStandardPaths::AppConfigLocation) + "/preferences.ini"
          : file, QSettings::IniFormat)
    , m_hadSettings(!m_settings.allKeys().isEmpty())
{}
namespace {
QVariantMap normalizedPalette(const QVariantMap &input, bool *valid)
{
    static const QStringList roles{"rail", "base", "mantle", "surface", "surfaceHi", "rowAlt", "inset", "hero", "heroLine",
        "border", "outline", "text", "subtext", "bone", "brass", "accentInk", "warning", "danger", "success"};
    QVariantMap result;
    *valid = true;
    for (auto theme = input.cbegin(); theme != input.cend(); ++theme) {
        if (theme.key() != "deep" && theme.key() != "light") { *valid = false; return {}; }
        if (!theme.value().canConvert<QVariantMap>()) { *valid = false; return {}; }
        const auto colours = theme.value().toMap();
        QVariantMap cleaned;
        for (auto role = colours.cbegin(); role != colours.cend(); ++role) {
            const QColor colour(role.value().toString());
            if (!roles.contains(role.key()) || !colour.isValid() || colour.alpha() != 255) { *valid = false; return {}; }
            cleaned.insert(role.key(), colour.name());
        }
        if (!cleaned.isEmpty()) result.insert(theme.key(), cleaned);
    }
    return result;
}
}
QVariantMap AppPreferences::paletteOverrides() const
{
    bool valid = false;
    return normalizedPalette(QJsonDocument::fromJson(m_settings.value("interface/paletteOverrides").toByteArray()).object().toVariantMap(), &valid);
}
void AppPreferences::setPaletteOverrides(const QVariantMap &value)
{
    bool valid = false;
    const auto normalized = normalizedPalette(value, &valid);
    if (!valid) { emit errorOccurred("Use opaque colours for the supported Deep sea and Light palette roles."); return; }
    if (normalized == paletteOverrides()) return;
    save("interface/paletteOverrides", QJsonDocument(QJsonObject::fromVariantMap(normalized)).toJson(QJsonDocument::Compact));
}
QString AppPreferences::cornerStyle() const { return m_settings.value("interface/corners").toString() == "angular" ? "angular" : "rounded"; }
void AppPreferences::setCornerStyle(const QString &value) { if (value == "rounded" || value == "angular") save("interface/corners", value); }
int AppPreferences::coverSize() const { const int value = m_settings.value("library/coverSize", 0).toInt(); return value == 170 || value == 220 || value == 280 ? value : 0; }
void AppPreferences::setCoverSize(int value) { if (value == 0 || value == 170 || value == 220 || value == 280) save("library/coverSize", value); }
bool AppPreferences::showCoverBadges() const { return m_settings.value("library/badges", true).toBool(); }
void AppPreferences::setShowCoverBadges(bool value) { save("library/badges", value); }
int AppPreferences::interfaceSize() const {
    const int value = m_settings.value("interface/size", 100).toInt();
    return value == 90 || value == 115 ? value : 100;
}
void AppPreferences::setInterfaceSize(int value) {
    if (value == 90 || value == 100 || value == 115) save("interface/size", value);
}
QString AppPreferences::libraryDensity() const {
    const QString value = m_settings.value("library/density", "comfortable").toString();
    return value == "compact" ? value : QStringLiteral("comfortable");
}
void AppPreferences::setLibraryDensity(const QString &value) {
    if (value == "compact" || value == "comfortable") save("library/density", value);
}
QStringList AppPreferences::homeSections() const {
    const QStringList allowed{"recent", "servers", "worlds", "stats", "news", "playtime"};
    const auto stored = m_settings.value("home/sections", allowed).toStringList();
    QStringList result;
    for (const auto &key : allowed) if (stored.contains(key)) result.append(key);
    return result;
}
void AppPreferences::setHomeSections(const QStringList &value) {
    const QStringList allowed{"recent", "servers", "worlds", "stats", "news", "playtime"};
    QStringList filtered;
    for (const auto &key : allowed) if (value.contains(key)) filtered.append(key);
    save("home/sections", filtered);
}
int AppPreferences::sidebarWidth() const { return qBound(190, m_settings.value("library/sidebarWidth", 248).toInt(), 420); }
void AppPreferences::setSidebarWidth(int value) {
    value = qBound(190, value, 420);
    if (value == sidebarWidth()) return;
    m_settings.setValue("library/sidebarWidth", value);
    emit sidebarWidthChanged();
}
QString AppPreferences::libraryView() const { return m_settings.value("interface/libraryView", "covers").toString(); }
QString AppPreferences::sortOrder() const { return m_settings.value("interface/sortOrder", "recent").toString(); }
QString AppPreferences::startPage() const { return m_settings.value("interface/startPage", "library").toString(); }
bool AppPreferences::showScreenshots() const { return m_settings.value("interface/screenshots", false).toBool(); }
bool AppPreferences::animations() const { return m_settings.value("interface/animations", true).toBool(); }
bool AppPreferences::decoFrames() const { return m_settings.value("interface/decoFrames", true).toBool(); }
// People upgrading with existing preferences already chose Prismarine; only a fresh profile sees the welcome.
bool AppPreferences::firstRunSeen() const { return m_settings.value("interface/firstRunSeen", m_hadSettings).toBool(); }
QColor AppPreferences::accentColor() const { return QColor(m_settings.value("interface/accent", "#46d1bb").toString()); }
QString AppPreferences::theme() const { return m_settings.value("interface/theme", "deep").toString(); }
QStringList AppPreferences::favorites() const { return m_settings.value("library/favorites").toStringList(); }
QVariantMap AppPreferences::notes() const { return m_settings.value("library/notes").toMap(); }
QVariantMap AppPreferences::covers() const { return m_settings.value("library/covers").toMap(); }
void AppPreferences::save(const QString &key, const QVariant &value)
{
    if (m_settings.contains(key) && m_settings.value(key) == value) return;
    m_settings.setValue(key, value);
    emit changed();
}
void AppPreferences::setLibraryView(const QString &v) { if (v == "covers" || v == "rows") save("interface/libraryView", v); }
void AppPreferences::setSortOrder(const QString &v) { if (v == "recent" || v == "name" || v == "mods") save("interface/sortOrder", v); }
void AppPreferences::setStartPage(const QString &v) { if (v == "home" || v == "library") save("interface/startPage", v); }
void AppPreferences::setShowScreenshots(bool v) { save("interface/screenshots", v); }
void AppPreferences::setAnimations(bool v) { save("interface/animations", v); }
void AppPreferences::setDecoFrames(bool v) { save("interface/decoFrames", v); }
void AppPreferences::setFirstRunSeen(bool v) { save("interface/firstRunSeen", v); }
void AppPreferences::setAccentColor(const QColor &v) { if (v.isValid()) save("interface/accent", v.name()); }
void AppPreferences::setTheme(const QString &v) { if (v == "deep" || v == "light" || v == "system") save("interface/theme", v); }
void AppPreferences::toggleFavorite(const QString &id)
{
    if (id.isEmpty()) return;
    auto list = favorites();
    if (list.contains(id)) list.removeAll(id); else list.append(id);
    m_settings.setValue("library/favorites", list);
    emit favoritesChanged();
}
void AppPreferences::setNote(const QString &id, const QString &text)
{
    if (id.isEmpty()) return;
    auto map = notes();
    if (map.value(id).toString() == text) return;
    map.insert(id, text);
    m_settings.setValue("library/notes", map);
    emit notesChanged();
}
// Instance artwork: per instance a "card" and a "hero" (banner) choice of
// "" (follow the global screenshot switch), "art", "screenshot" or "image".
// Older single covers ("library/covers") count as an image for both.
QVariantMap AppPreferences::artwork() const
{
    QVariantMap result;
    const auto legacy = covers();
    for (auto it = legacy.cbegin(); it != legacy.cend(); ++it) {
        const QVariantMap image{{"mode", "image"}, {"url", it.value()}};
        result.insert(it.key(), QVariantMap{{"card", image}, {"hero", image}});
    }
    const auto stored = QJsonDocument::fromJson(m_settings.value("library/artwork").toByteArray()).object().toVariantMap();
    for (auto it = stored.cbegin(); it != stored.cend(); ++it) result.insert(it.key(), it.value());
    return result;
}

QString AppPreferences::coversDir() const
{
    // Next to the preferences file, so an isolated --preferences session keeps its own images.
    return QFileInfo(m_settings.fileName()).absolutePath() + "/covers";
}

bool AppPreferences::setArtwork(const QString &id, const QString &slot, const QString &mode, const QUrl &url)
{
    if (id.isEmpty() || !QStringList{"card", "hero", "both"}.contains(slot) || !QStringList{"", "art", "screenshot", "image"}.contains(mode))
        return false;
    QString stored;
    if (mode == "image") {
        const QString source = url.toLocalFile();
        QImageReader reader(source);
        if (!url.isLocalFile() || !reader.canRead() || QFileInfo(source).size() > 25 * 1024 * 1024) {
            emit errorOccurred("Choose a readable image from your computer, up to 25 MB.");
            return false;
        }
        // A private copy keeps the cover when the original or the screenshot is moved or cleaned up.
        if (QFileInfo(source).absolutePath() == coversDir()) stored = url.toString();
        else {
            QFile file(source);
            if (!file.open(QIODevice::ReadOnly)) { emit errorOccurred("Could not read this image."); return false; }
            const QByteArray bytes = file.readAll();
            const QString name = QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha1).toHex().left(16)) + "." + QFileInfo(source).suffix().toLower();
            QDir().mkpath(coversDir());
            QSaveFile copy(coversDir() + "/" + name);
            if (!QFile::exists(copy.fileName()) && (!copy.open(QIODevice::WriteOnly) || copy.write(bytes) != bytes.size() || !copy.commit())) {
                emit errorOccurred("Could not save a copy of this image.");
                return false;
            }
            stored = QUrl::fromLocalFile(coversDir() + "/" + name).toString();
        }
    }
    QJsonObject all = QJsonDocument::fromJson(m_settings.value("library/artwork").toByteArray()).object();
    QJsonObject entry = all.value(id).toObject();
    if (entry.isEmpty()) {
        // Carry an old single cover over before changing one side of it.
        const QString legacy = covers().value(id).toString();
        if (!legacy.isEmpty()) { const QJsonObject image{{"mode", "image"}, {"url", legacy}}; entry = {{"card", image}, {"hero", image}}; }
    }
    const QJsonObject choice{{"mode", mode}, {"url", stored}};
    for (const QString &side : slot == "both" ? QStringList{"card", "hero"} : QStringList{slot})
        entry.insert(side, choice);
    all.insert(id, entry);
    m_settings.setValue("library/artwork", QJsonDocument(all).toJson(QJsonDocument::Compact));
    auto legacy = covers();
    if (legacy.remove(id)) m_settings.setValue("library/covers", legacy);
    emit coversChanged();
    return true;
}

bool AppPreferences::setCover(const QString &id, const QUrl &url)
{
    return setArtwork(id, "both", "image", url);
}

void AppPreferences::clearCover(const QString &id)
{
    setArtwork(id, "both", "", {});
}
void AppPreferences::sync()
{
    m_settings.sync();
    if (m_settings.status() != QSettings::NoError)
        emit errorOccurred("Could not save your Prismarine preferences.");
}

bool AppPreferences::multiAccount() const { return m_settings.value("experimental/multiAccount", false).toBool(); }
void AppPreferences::setMultiAccount(bool v) { save("experimental/multiAccount", v); }
int AppPreferences::scrollSpeed() const
{
    const int value = m_settings.value("interface/scrollSpeed", 2).toInt();
    return value >= 1 && value <= 3 ? value : 2;
}
void AppPreferences::setScrollSpeed(int value)
{
    if (value >= 1 && value <= 3) save("interface/scrollSpeed", value);
}
bool AppPreferences::controllerEnabled() const { return m_settings.value("features/controller", true).toBool(); }
void AppPreferences::setControllerEnabled(bool v) { save("features/controller", v); }
bool AppPreferences::friendsEnabled() const { return m_settings.value("features/friends", false).toBool(); }
bool AppPreferences::hasFriendsChoice() const { return m_settings.contains("features/friends"); }
void AppPreferences::setFriendsEnabled(bool v) { save("features/friends", v); }
bool AppPreferences::prismShortcuts() const { return m_settings.value("features/prismShortcuts", true).toBool(); }
void AppPreferences::setPrismShortcuts(bool v) { save("features/prismShortcuts", v); }
QString AppPreferences::startInterface() const
{
    const QString value = m_settings.value("interface/startInterface", "desktop").toString();
    return value == "handheld" ? value : QStringLiteral("desktop");
}
void AppPreferences::setStartInterface(const QString &value)
{
    if (value == "desktop" || value == "handheld") save("interface/startInterface", value);
}

QVariantList AppPreferences::serverFavorites() const
{
    return QJsonDocument::fromJson(m_settings.value("home/serverFavorites").toByteArray()).array().toVariantList();
}

bool AppPreferences::isServerFavorite(const QString &instanceId, const QString &address) const
{
    for (const auto &value : serverFavorites()) {
        const auto entry = value.toMap();
        if (entry.value("instanceId") == instanceId && entry.value("address").toString().compare(address, Qt::CaseInsensitive) == 0) return true;
    }
    return false;
}

bool AppPreferences::addServerFavorite(const QString &instanceId, const QString &name, const QString &input)
{
    const QString address = input.trimmed();
    static const QRegularExpression port(QStringLiteral(":([0-9]+)$"));
    const auto match = port.match(address);
    if (instanceId.isEmpty() || !ServerList::validAddress(address)
        || (match.hasMatch() && (match.captured(1).toUInt() == 0 || match.captured(1).toUInt() > 65535))) {
        emit errorOccurred("Enter a valid server address and select an instance.");
        return false;
    }
    if (isServerFavorite(instanceId, address)) return true;
    auto list = QJsonArray::fromVariantList(serverFavorites());
    list.append(QJsonObject{{"instanceId", instanceId}, {"name", name.trimmed().isEmpty() ? address : name.trimmed().left(120)}, {"address", address}});
    m_settings.setValue("home/serverFavorites", QJsonDocument(list).toJson(QJsonDocument::Compact));
    emit serverFavoritesChanged();
    return true;
}

void AppPreferences::toggleServerFavorite(const QString &instanceId, const QString &name, const QString &address)
{
    if (instanceId.isEmpty() || address.isEmpty() || address.size() > 255) return;
    QJsonArray list = QJsonArray::fromVariantList(serverFavorites());
    bool removed = false;
    for (int i = list.size() - 1; i >= 0; --i) {
        const auto entry = list.at(i).toObject();
        if (entry.value("instanceId") == instanceId && entry.value("address").toString().compare(address, Qt::CaseInsensitive) == 0) { list.removeAt(i); removed = true; }
    }
    if (!removed) list.append(QJsonObject{{"instanceId", instanceId}, {"name", name.left(120)}, {"address", address}});
    m_settings.setValue("home/serverFavorites", QJsonDocument(list).toJson(QJsonDocument::Compact));
    emit serverFavoritesChanged();
}

static bool validWhilePlaying(const QString &value)
{
    return value == "keep" || value == "minimize" || value == "hide";
}

QString AppPreferences::whilePlaying() const
{
    const QString value = m_settings.value("interface/whilePlaying", "keep").toString();
    return validWhilePlaying(value) ? value : "keep";
}

void AppPreferences::setWhilePlaying(const QString &v)
{
    if (validWhilePlaying(v)) save("interface/whilePlaying", v);
}

QVariantMap AppPreferences::instanceWhilePlaying() const
{
    return QJsonDocument::fromJson(m_settings.value("library/whilePlaying").toByteArray()).object().toVariantMap();
}

void AppPreferences::setInstanceWhilePlaying(const QString &id, const QString &value)
{
    if (id.isEmpty() || (!value.isEmpty() && !validWhilePlaying(value))) return;
    QJsonObject map = QJsonObject::fromVariantMap(instanceWhilePlaying());
    if (value.isEmpty()) map.remove(id); else map.insert(id, value);
    save("library/whilePlaying", QJsonDocument(map).toJson(QJsonDocument::Compact));
}

QString AppPreferences::whilePlayingFor(const QString &id) const
{
    const QString own = instanceWhilePlaying().value(id).toString();
    return validWhilePlaying(own) ? own : whilePlaying();
}

bool AppPreferences::prismConsole() const { return m_settings.value("launch/prismConsole", false).toBool(); }
void AppPreferences::setPrismConsole(bool v) { save("launch/prismConsole", v); }

QString AppPreferences::prismProgram() const { return m_settings.value("launch/prismProgram").toString(); }
void AppPreferences::setPrismProgram(const QString &v) { save("launch/prismProgram", v.trimmed()); }
void AppPreferences::setPrismProgramFromUrl(const QUrl &url)
{
    if (url.isLocalFile()) setPrismProgram(url.toLocalFile());
}
