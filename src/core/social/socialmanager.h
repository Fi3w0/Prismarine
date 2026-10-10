#pragma once
#include <QObject>
#include <QJsonArray>
#include <QLockFile>
#include <QNetworkAccessManager>
#include <QPointer>
#include <QUrl>
#include <QVariantList>
#include <memory>
#include <functional>
#include "landiscovery.h"
#include "socialprotocol.h"
class AccountManager;
class IdentityStore;
class QNetworkReply;
class QTemporaryDir;

class SocialManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(bool available READ available CONSTANT)
    Q_PROPERTY(bool ready READ ready NOTIFY changed)
    Q_PROPERTY(bool busy READ busy NOTIFY changed)
    Q_PROPERTY(bool exists READ exists NOTIFY changed)
    Q_PROPERTY(QString name READ name NOTIFY changed)
    Q_PROPERTY(QString fingerprint READ fingerprint NOTIFY changed)
    Q_PROPERTY(QVariantList accounts READ accounts NOTIFY changed)
    Q_PROPERTY(QVariantList friends READ friends NOTIFY changed)
    Q_PROPERTY(QVariantMap pendingFriend READ pendingFriend NOTIFY changed)
    Q_PROPERTY(QVariantMap pendingInvite READ pendingInvite NOTIFY changed)
    Q_PROPERTY(bool discovering READ discovering NOTIFY changed)
public:
    explicit SocialManager(AccountManager *accounts, QObject *parent = nullptr, const QString &dataDir = {},
                           IdentityStore *store = nullptr, const QList<QByteArray> &roots = {},
                           const QUrl &minecraftApi = QUrl("https://api.minecraftservices.com"));
    ~SocialManager() override;
    bool available() const;
    bool ready() const { return m_seed.size() == 32; }
    bool busy() const { return m_busy; }
    bool exists() const { return !m_publicKey.isEmpty(); }
    QString name() const { return m_name; }
    QString fingerprint() const;
    QVariantList accounts() const;
    QVariantList friends() const;
    QVariantMap pendingFriend() const;
    QVariantMap pendingInvite() const;
    bool discovering() const { return m_lan.active(); }
    Q_INVOKABLE void unlock(const QString &newName = {});
    Q_INVOKABLE void lock();
    Q_INVOKABLE bool rename(const QString &name);
    Q_INVOKABLE void linkAccount(const QString &uuid);
    Q_INVOKABLE bool unlinkAccount(const QString &uuid);
    Q_INVOKABLE bool exportCard(const QUrl &destination);
    Q_INVOKABLE bool reviewFriend(const QUrl &source);
    Q_INVOKABLE bool acceptFriend();
    Q_INVOKABLE void clearReview();
    Q_INVOKABLE bool removeFriend(const QString &key);
    Q_INVOKABLE void setDiscovering(bool enabled);
    Q_INVOKABLE void exportInvite(const QString &friendKey, const QString &title, const QString &server,
                                  const QUrl &pack, const QUrl &destination);
    Q_INVOKABLE bool reviewInvite(const QUrl &source);
    Q_INVOKABLE bool joinInvite(const QString &instanceId);
    Q_INVOKABLE void importInvitedPack(const QUrl &source);
signals:
    void changed();
    void errorOccurred(const QString &message);
    void notice(const QString &message);
    void joinRequested(const QString &instanceId, const QString &address);
    void packReady(const QUrl &file);
private:
    bool fail(const QString &error);
    bool writable();
    bool load();
    bool save();
    QByteArray readDocument(const QUrl &source);
    bool writeDocument(const QUrl &destination, const QByteArray &document);
    QByteArray card() const;
    QVariantMap describeCard(const QByteArray &document) const;
    QSet<QByteArray> friendKeys() const;
    bool validPendingInvite();
    bool consumeInvite();
    void hashPack(const QUrl &source, std::function<void(QString, QString)> done);
    AccountManager *m_accounts;
    IdentityStore *m_store;
    QString m_dir, m_storeKey, m_name, m_loadError;
    QByteArray m_seed, m_publicKey, m_reviewCard, m_reviewInvite;
    QJsonArray m_links, m_contacts;
    QJsonObject m_usedInvites;
    bool m_busy = false, m_inviteAccepted = false;
    quint64 m_generation = 0;
    QList<QByteArray> m_roots;
    QUrl m_api;
    QNetworkAccessManager m_network;
    QPointer<QNetworkReply> m_reply;
    std::unique_ptr<QLockFile> m_lock;
    LanDiscovery m_lan;
    QList<std::shared_ptr<QTemporaryDir>> m_stagedPacks;
};
