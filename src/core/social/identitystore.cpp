#include "identitystore.h"
#include <QTimer>
#ifdef PRISMARINE_HAS_KEYCHAIN
#include <qt6keychain/keychain.h>
#endif
namespace {
class SystemStore final : public IdentityStore {
public:
    using IdentityStore::IdentityStore;
    bool available() const override {
#ifdef PRISMARINE_HAS_KEYCHAIN
        return true;
#else
        return false;
#endif
    }
    void read(const QString &key, ReadDone done) override {
#ifdef PRISMARINE_HAS_KEYCHAIN
        auto *job = new QKeychain::ReadPasswordJob("Prismarine", this);
        job->setKey(key); job->setInsecureFallback(false);
        connect(job, &QKeychain::Job::finished, this, [job, done] {
            const bool missing = job->error() == QKeychain::EntryNotFound;
            done(job->error() ? QByteArray() : job->binaryData(), missing,
                 job->error() && !missing ? QStringLiteral("Cannot unlock the system keyring. Unlock it and try again.") : QString());
        });
        job->start();
#else
        Q_UNUSED(key)
        QTimer::singleShot(0, this, [done] { done({}, false, "This build needs QtKeychain to store an identity securely."); });
#endif
    }
    void write(const QString &key, const QByteArray &seed, WriteDone done) override {
#ifdef PRISMARINE_HAS_KEYCHAIN
        auto *job = new QKeychain::WritePasswordJob("Prismarine", this);
        job->setKey(key); job->setInsecureFallback(false); job->setBinaryData(seed);
        connect(job, &QKeychain::Job::finished, this, [job, done] {
            done(job->error() ? QStringLiteral("Cannot save the identity in the system keyring. Nothing was saved in plain text.") : QString());
        });
        job->start();
#else
        Q_UNUSED(key) Q_UNUSED(seed)
        QTimer::singleShot(0, this, [done] { done("This build needs QtKeychain to store an identity securely."); });
#endif
    }
};
}
IdentityStore *systemIdentityStore(QObject *parent) { return new SystemStore(parent); }
