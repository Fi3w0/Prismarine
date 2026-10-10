#include "socialmanager.h"
#include "identitystore.h"
#include "crypto.h"
#include "mojangkeys.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QFutureWatcher>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QSaveFile>
#include <QStandardPaths>
#include <QTemporaryDir>
#include <QUuid>
#include <QtConcurrent>

namespace {
qint64 now() { return QDateTime::currentMSecsSinceEpoch(); }
constexpr int MaxFriends = 100;
QVariantList describeLinks(const QJsonArray &links) {
    QVariantList result;
    for (const auto &value : links) {
        const auto link = value.toObject();
        const auto expires = QDateTime::fromString(link.value("expiresAt").toString(), Qt::ISODateWithMs);
        result.append(QVariantMap{{"uuid", link.value("uuid").toString()}, {"name", link.value("name").toString()},
            {"current", expires.toMSecsSinceEpoch() > now()}, {"expires", expires.toLocalTime().toString("yyyy-MM-dd HH:mm")}});
    }
    return result;
}
}
SocialManager::SocialManager(AccountManager *accounts, QObject *parent, const QString &dataDir,
                             IdentityStore *store, const QList<QByteArray> &roots, const QUrl &minecraftApi)
    : QObject(parent), m_accounts(accounts), m_store(store ? store : systemIdentityStore(this)),
      m_dir(dataDir.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/social" : dataDir),
      m_roots(roots.isEmpty() ? mojangCertificateRoots() : roots), m_api(minecraftApi)
{
    m_dir = QDir(m_dir).absolutePath();
    m_storeKey = "identity-v1-" + QString::fromLatin1(QCryptographicHash::hash(m_dir.toUtf8(), QCryptographicHash::Sha256).toHex());
    load();
    connect(&m_lan, &LanDiscovery::changed, this, &SocialManager::changed);
    // Certificate badges expire even when the page remains open overnight.
    auto *timer = new QTimer(this); timer->setInterval(30000);
    connect(timer, &QTimer::timeout, this, &SocialManager::changed); timer->start();
}
SocialManager::~SocialManager() { lock(); }
bool SocialManager::available() const { return m_store->available(); }
QString SocialManager::fingerprint() const { return exists() ? Crypto::fingerprint(m_publicKey) : QString(); }
QVariantList SocialManager::accounts() const { return describeLinks(m_links); }
bool SocialManager::fail(const QString &error) { emit errorOccurred(error); return false; }
bool SocialManager::writable() { return ready() && !m_busy ? true : fail("Unlock your Prismarine identity and wait for the current operation to finish."); }

bool SocialManager::load()
{
    QFile file(m_dir + "/identity.json");
    if (!file.exists()) return true;
    const auto invalid = [this] { m_loadError = "The saved identity cannot be read. It has been left untouched; restore your social folder from backup."; return false; };
    if (!file.open(QIODevice::ReadOnly) || file.size() > 20 * 1024 * 1024) return invalid();
    QJsonParseError parse;
    const auto state = QJsonDocument::fromJson(file.readAll(), &parse).object();
    const QByteArray key = Crypto::fromBase64Url(state.value("publicKey").toString());
    if (parse.error != QJsonParseError::NoError || state.value("version").toInt() != 1 || key.size() != 32
        || !SocialProtocol::validLabel(state.value("name").toString()) || !state.value("accounts").isArray()
        || !state.value("friends").isArray() || !state.value("usedInvites").isObject()) return invalid();
    const auto links = state.value("accounts").toArray(), contacts = state.value("friends").toArray();
    SocialProtocol::Verified own{{{"name", state.value("name")}, {"accounts", links}}, key, {}};
    if (!SocialProtocol::verifyCard(own, m_roots, now(), true).isEmpty() || contacts.size() > MaxFriends) return invalid();
    QSet<QByteArray> seen;
    for (const auto &value : contacts) {
        const auto card = SocialProtocol::open(Crypto::fromBase64Url(value.toString()), "card");
        if (!card || !SocialProtocol::verifyCard(card, m_roots, now(), true).isEmpty() || seen.contains(card.publicKey) || card.publicKey == key) return invalid();
        seen.insert(card.publicKey);
    }
    m_publicKey = key; m_name = state.value("name").toString(); m_links = links; m_contacts = contacts;
    m_usedInvites = state.value("usedInvites").toObject();
    return true;
}
bool SocialManager::save()
{
    if (!m_lock || !m_lock->isLocked() || !ready()) return fail("The identity is locked.");
    const QJsonObject state{{"version", 1}, {"publicKey", Crypto::base64Url(m_publicKey)}, {"name", m_name},
        {"accounts", m_links}, {"friends", m_contacts}, {"usedInvites", m_usedInvites}};
    const auto bytes = QJsonDocument(state).toJson();
    QSaveFile output(m_dir + "/identity.json");
    if (!output.open(QIODevice::WriteOnly) || !output.setPermissions(QFile::ReadOwner | QFile::WriteOwner)
        || output.write(bytes) != bytes.size() || !output.commit()) return fail("Cannot save your social profile. The previous file is unchanged.");
    emit changed(); return true;
}
void SocialManager::unlock(const QString &newName)
{
    if (ready() || m_busy) return;
    if (!m_loadError.isEmpty()) { fail(m_loadError); return; }
    if (!available()) { fail("This build needs QtKeychain to use a Prismarine identity."); return; }
    if (!exists() && !SocialProtocol::validLabel(newName)) { fail("Choose a name of 1–64 visible characters."); return; }
    if (!QDir().mkpath(m_dir)) { fail("Cannot create the social profile folder."); return; }
    QFile::setPermissions(m_dir, QFile::ReadOwner | QFile::WriteOwner | QFile::ExeOwner);
    m_lock = std::make_unique<QLockFile>(m_dir + "/identity.lock");
    if (!m_lock->tryLock()) { m_lock.reset(); fail("Your social profile is open in another Prismarine window."); return; }
    // Re-read after taking the lock so another process cannot be overwritten with stale state.
    if (!load()) { m_lock.reset(); fail(m_loadError); return; }
    m_busy = true; emit changed();
    const quint64 generation = ++m_generation;
    const QPointer<SocialManager> guard(this);
    m_store->read(m_storeKey, [this, guard, generation, newName](QByteArray seed, bool missing, const QString &error) {
        if (!guard || generation != m_generation) { Crypto::clearSecret(seed); return; }
        const auto finish = [this, guard, generation](QByteArray value, const QString &storeError) {
            if (!guard || generation != m_generation) { Crypto::clearSecret(value); return; }
            m_busy = false;
            const auto key = Crypto::publicFromSeed(value);
            if (!storeError.isEmpty() || key.isEmpty() || (exists() && key != m_publicKey)) {
                Crypto::clearSecret(value); m_lock.reset(); emit changed();
                fail(storeError.isEmpty() ? "The system keyring does not contain the matching identity key. No replacement was created." : storeError); return;
            }
            m_seed = value; m_publicKey = key;
            if (!save()) { lock(); return; }
            emit notice("Prismarine identity unlocked");
        };
        if (!error.isEmpty()) { finish({}, error); return; }
        if (!exists()) m_name = newName.trimmed();
        if (missing && exists()) { finish({}, "The identity key is missing from your system keyring. Restore the original keyring; a new key would be a different identity."); return; }
        if (!missing) { finish(seed, {}); return; }
        auto pair = Crypto::generateEd25519();
        if (pair.privateSeed.size() != 32) { finish({}, "Cannot generate a secure identity key."); return; }
        m_store->write(m_storeKey, pair.privateSeed, [finish, seed = pair.privateSeed](const QString &writeError) { finish(seed, writeError); });
    });
}
void SocialManager::lock()
{
    ++m_generation;
    if (m_reply) m_reply->abort();
    m_busy = false; m_lan.stop(); Crypto::clearSecret(m_seed); m_lock.reset(); clearReview(); emit changed();
}
bool SocialManager::rename(const QString &name)
{
    if (!writable()) return false;
    if (!SocialProtocol::validLabel(name)) return fail("Choose a name of 1–64 visible characters.");
    const QString previous = m_name; m_name = name.trimmed();
    if (!save()) { m_name = previous; return false; } return true;
}
bool SocialManager::unlinkAccount(const QString &uuid)
{
    if (!writable()) return false;
    const auto previous = m_links;
    for (int i = m_links.size() - 1; i >= 0; --i) if (m_links[i].toObject().value("uuid").toString() == uuid) m_links.removeAt(i);
    if (!save()) { m_links = previous; return false; }
    emit notice("Account unlinked here. Previously shared proofs remain valid until their expiry."); return true;
}
QByteArray SocialManager::card() const
{
    QJsonArray current;
    for (const auto &value : m_links)
        if (SocialProtocol::verifyLink(value.toObject(), m_publicKey, m_roots, now()).isEmpty()) current.append(value);
    return SocialProtocol::seal({{"type", "card"}, {"name", m_name}, {"accounts", current}}, m_seed);
}
QByteArray SocialManager::readDocument(const QUrl &source)
{
    QFile file(source.toLocalFile());
    if (!source.isLocalFile() || !file.open(QIODevice::ReadOnly) || file.size() > SocialProtocol::MaxDocument) {
        fail("Choose a local Prismarine social file smaller than 128 KiB."); return {};
    }
    return file.read(SocialProtocol::MaxDocument + 1);
}
bool SocialManager::writeDocument(const QUrl &destination, const QByteArray &document)
{
    if (!destination.isLocalFile() || document.isEmpty()) return fail("Choose a local destination file.");
    const QString path = QFileInfo(destination.toLocalFile()).absoluteFilePath();
    // Do not allow an export to overwrite social state or Prism's account file.
    if (path == m_dir || path.startsWith(m_dir + '/') || QFileInfo(path).fileName() == "accounts.json") return fail("Choose a destination outside the account storage folders.");
    QSaveFile output(path);
    if (!output.open(QIODevice::WriteOnly) || !output.setPermissions(QFile::ReadOwner | QFile::WriteOwner)
        || output.write(document) != document.size() || !output.commit()) return fail("Cannot save this social file.");
    emit notice("Saved " + QFileInfo(path).fileName()); return true;
}
bool SocialManager::exportCard(const QUrl &destination) { return writable() && writeDocument(destination, card()); }
QVariantMap SocialManager::describeCard(const QByteArray &document) const
{
    const auto verified = SocialProtocol::open(document, "card");
    if (!verified) return {};
    return {{"key", Crypto::base64Url(verified.publicKey)}, {"name", verified.payload.value("name").toString()},
        {"fingerprint", Crypto::fingerprint(verified.publicKey)}, {"accounts", describeLinks(verified.payload.value("accounts").toArray())}};
}
QVariantMap SocialManager::pendingFriend() const { return describeCard(m_reviewCard); }
QSet<QByteArray> SocialManager::friendKeys() const
{
    QSet<QByteArray> keys;
    for (const auto &value : m_contacts) keys.insert(SocialProtocol::open(Crypto::fromBase64Url(value.toString()), "card").publicKey);
    return keys;
}
QVariantList SocialManager::friends() const
{
    QVariantList result;
    const auto nearby = m_lan.peers();
    for (const auto &value : m_contacts) {
        auto contact = describeCard(Crypto::fromBase64Url(value.toString()));
        contact.insert("nearby", false);
        for (const auto &peer : nearby) if (peer.toMap().value("key") == contact.value("key")) contact.insert("nearby", true);
        result.append(contact);
    }
    return result;
}
bool SocialManager::reviewFriend(const QUrl &source)
{
    m_reviewCard.clear(); emit changed();
    if (!writable()) return false;
    const auto bytes = readDocument(source); if (bytes.isEmpty()) return false;
    const auto verified = SocialProtocol::open(bytes, "card");
    const auto error = verified ? SocialProtocol::verifyCard(verified, m_roots, now()) : verified.error;
    if (!error.isEmpty()) return fail(error);
    if (verified.publicKey == m_publicKey) return fail("This is your own friend card.");
    m_reviewCard = bytes; emit changed(); return true;
}
bool SocialManager::acceptFriend()
{
    if (!writable() || m_reviewCard.isEmpty()) return false;
    const auto verified = SocialProtocol::open(m_reviewCard, "card");
    const auto error = SocialProtocol::verifyCard(verified, m_roots, now());
    if (!error.isEmpty()) return fail(error);
    const auto previous = m_contacts;
    int found = -1;
    for (int i = 0; i < m_contacts.size(); ++i)
        if (SocialProtocol::open(Crypto::fromBase64Url(m_contacts[i].toString()), "card").publicKey == verified.publicKey) found = i;
    if (found >= 0) m_contacts[found] = Crypto::base64Url(m_reviewCard);
    else {
        if (m_contacts.size() >= MaxFriends) return fail("Your friend list is full (100 contacts).");
        m_contacts.append(Crypto::base64Url(m_reviewCard));
    }
    if (!save()) { m_contacts = previous; return false; }
    m_reviewCard.clear(); m_lan.setFriends(friendKeys()); emit changed(); emit notice("Friend card saved"); return true;
}
void SocialManager::clearReview() { m_reviewCard.clear(); m_reviewInvite.clear(); m_inviteAccepted = false; emit changed(); }
bool SocialManager::removeFriend(const QString &key)
{
    if (!writable()) return false;
    const auto previous = m_contacts;
    for (int i = m_contacts.size() - 1; i >= 0; --i)
        if (SocialProtocol::open(Crypto::fromBase64Url(m_contacts[i].toString()), "card").publicKey == Crypto::fromBase64Url(key)) m_contacts.removeAt(i);
    if (!save()) { m_contacts = previous; return false; }
    clearReview(); m_lan.setFriends(friendKeys()); emit changed(); return true;
}
void SocialManager::setDiscovering(bool enabled)
{
    if (!enabled) { m_lan.stop(); return; }
    if (writable() && !m_lan.start(m_seed, friendKeys())) fail("LAN discovery could not start. Check your network and firewall.");
}
void SocialManager::hashPack(const QUrl &source, std::function<void(QString, QString)> done)
{
    const QFileInfo info(source.toLocalFile());
    if (!source.isLocalFile() || !info.isFile() || (info.suffix().toLower() != "mrpack" && info.suffix().toLower() != "zip")) {
        done({}, "Choose a local .mrpack or .zip file."); return;
    }
    m_busy = true; emit changed();
    const auto generation = m_generation;
    auto *watcher = new QFutureWatcher<QPair<QString, QString>>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher, generation, done] {
        const auto result = watcher->result(); watcher->deleteLater();
        if (generation != m_generation) return;
        m_busy = false; emit changed(); done(result.first, result.second);
    });
    watcher->setFuture(QtConcurrent::run([path = info.filePath()] {
        QFile file(path); QCryptographicHash hash(QCryptographicHash::Sha256);
        if (!file.open(QIODevice::ReadOnly) || !hash.addData(&file)) return qMakePair(QString(), QStringLiteral("Cannot read this pack."));
        return qMakePair(QString::fromLatin1(hash.result().toHex()), QString());
    }));
}
void SocialManager::exportInvite(const QString &friendKey, const QString &title, const QString &server,
                                  const QUrl &pack, const QUrl &destination)
{
    if (!writable()) return;
    const auto recipient = Crypto::fromBase64Url(friendKey);
    if (!friendKeys().contains(recipient)) { fail("Choose a saved friend."); return; }
    if (!SocialProtocol::validLabel(title) || (!server.isEmpty() && !SocialProtocol::validServer(server)) || (server.isEmpty() && pack.isEmpty())) {
        fail("Give the invite a title and a valid server address or pack."); return;
    }
    const auto finish = [this, recipient, title, server, pack, destination](const QString &hash, const QString &error) {
        if (!error.isEmpty()) { fail(error); return; }
        QJsonObject p{{"type", "invite"}, {"id", QUuid::createUuid().toString(QUuid::WithoutBraces)},
            {"recipient", Crypto::base64Url(recipient)}, {"title", title}, {"server", server}, {"issued", now()}, {"expires", now() + 7LL * 86400000}};
        if (!pack.isEmpty()) p.insert("pack", QJsonObject{{"name", QFileInfo(pack.toLocalFile()).fileName()}, {"sha256", hash}});
        const auto document = SocialProtocol::seal(p, m_seed);
        const auto validation = SocialProtocol::verifyInvite(SocialProtocol::open(document, "invite"), recipient, now());
        if (!validation.isEmpty()) { fail(validation); return; }
        writeDocument(destination, document);
    };
    if (pack.isEmpty()) finish({}, {}); else hashPack(pack, finish);
}
QVariantMap SocialManager::pendingInvite() const
{
    const auto verified = SocialProtocol::open(m_reviewInvite, "invite");
    if (!verified) return {};
    auto result = verified.payload.toVariantMap();
    result.insert("fingerprint", Crypto::fingerprint(verified.publicKey));
    for (const auto &contact : friends()) if (contact.toMap().value("key").toString() == Crypto::base64Url(verified.publicKey)) result.insert("from", contact.toMap().value("name"));
    return result;
}
bool SocialManager::validPendingInvite()
{
    const auto verified = SocialProtocol::open(m_reviewInvite, "invite");
    if (!verified) return fail(verified.error);
    const auto error = SocialProtocol::verifyInvite(verified, m_publicKey, now());
    if (!error.isEmpty()) return fail(error);
    if (!friendKeys().contains(verified.publicKey)) return fail("The sender is not a saved friend. Review their friend card first.");
    if (!m_inviteAccepted && m_usedInvites.contains(verified.payload.value("id").toString())) return fail("This invite has already been accepted.");
    return true;
}
bool SocialManager::reviewInvite(const QUrl &source)
{
    m_reviewInvite.clear(); m_inviteAccepted = false; emit changed();
    if (!writable()) return false;
    m_reviewInvite = readDocument(source);
    if (m_reviewInvite.isEmpty()) return false;
    if (!validPendingInvite()) { m_reviewInvite.clear(); return false; }
    emit changed(); return true;
}
bool SocialManager::consumeInvite()
{
    if (!validPendingInvite()) return false;
    if (m_inviteAccepted) return true;
    const auto p = SocialProtocol::open(m_reviewInvite, "invite").payload;
    const auto previous = m_usedInvites;
    for (auto it = m_usedInvites.begin(); it != m_usedInvites.end();) {
        if (it.value().toInteger() <= now()) it = m_usedInvites.erase(it); else ++it;
    }
    if (m_usedInvites.size() >= 1000) return fail("Too many recent invites. Try again after some expire.");
    m_usedInvites.insert(p.value("id").toString(), p.value("expires"));
    if (!save()) { m_usedInvites = previous; return false; }
    m_inviteAccepted = true; return true;
}
bool SocialManager::joinInvite(const QString &instanceId)
{
    if (!writable() || !validPendingInvite() || instanceId.isEmpty()) return false;
    const auto p = SocialProtocol::open(m_reviewInvite, "invite").payload;
    const auto address = p.value("server").toString();
    if (address.isEmpty() || !consumeInvite()) return false;
    emit joinRequested(instanceId, address); return true;
}
void SocialManager::importInvitedPack(const QUrl &source)
{
    if (!writable() || !validPendingInvite()) return;
    const auto expected = SocialProtocol::open(m_reviewInvite, "invite").payload.value("pack").toObject();
    if (expected.isEmpty()) { fail("This invite does not include a pack."); return; }
    // Snapshot to an owner-only temporary directory before hashing; the importer reads exactly these bytes.
    auto staging = std::make_shared<QTemporaryDir>();
    const QString extension = QFileInfo(source.toLocalFile()).suffix().toLower();
    if (!source.isLocalFile() || (extension != "mrpack" && extension != "zip") || !staging->isValid()) { fail("Choose a local .mrpack or .zip file."); return; }
    const QString path = staging->filePath("pack." + extension);
    m_busy = true; emit changed();
    const auto generation = m_generation;
    auto *watcher = new QFutureWatcher<bool>(this);
    connect(watcher, &QFutureWatcherBase::finished, this, [this, watcher, generation, staging, path, expected] {
        const bool copied = watcher->result(); watcher->deleteLater();
        if (generation != m_generation) return;
        m_busy = false; emit changed();
        if (!copied) { fail("Cannot prepare the pack for verification."); return; }
        hashPack(QUrl::fromLocalFile(path), [this, staging, path, expected](const QString &hash, const QString &error) {
            if (!error.isEmpty()) { fail(error); return; }
            if (hash != expected.value("sha256").toString()) { fail("This pack does not match the friend's signed invite. Nothing was imported."); return; }
            if (!consumeInvite()) return;
            m_stagedPacks.append(staging);
            emit packReady(QUrl::fromLocalFile(path));
        });
    });
    watcher->setFuture(QtConcurrent::run([source, path, staging] { return QFile::copy(source.toLocalFile(), path); }));
}
