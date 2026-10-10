#include "accountmanager.h"
#include <QCryptographicHash>
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QHttpMultiPart>
#include <QImage>
#include <QJsonDocument>
#include <QJsonObject>
#include <QNetworkReply>
#include <QRegularExpression>
#include <QSaveFile>
#include <QStandardPaths>

namespace {
constexpr qint64 MaxSkinBytes = 1024 * 1024;
}

AccountManager::AccountManager(InstanceModel *model, QObject *parent, const QUrl &apiRoot, const QString &skinsDir)
    : QObject(parent), m_model(model), m_apiRoot(apiRoot),
      m_skinsDir(skinsDir.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/skins" : skinsDir)
{
}

bool AccountManager::setDefault(const QString &id) { return update(id, false); }
bool AccountManager::remove(const QString &id) { return update(id, true); }

bool AccountManager::update(const QString &id, bool remove)
{
    bool found = false;
    const bool saved = editAccounts([&](QJsonArray &accounts) {
        QJsonArray kept;
        bool removedDefault = false;
        for (const auto &value : accounts) {
            auto account = value.toObject();
            const bool match = account.value("profile").toObject().value("id") == id;
            found |= match;
            if (remove && match) { removedDefault |= account.value("active").toBool(); continue; }
            if (!remove) account.insert("active", match);
            kept.append(account);
        }
        if (!found || id.isEmpty()) return false;
        if (removedDefault && !kept.isEmpty()) { auto a = kept.first().toObject(); a.insert("active", true); kept[0] = a; }
        accounts = kept;
        return true;
    });
    if (!saved && !found) emit errorOccurred("This account is no longer available.");
    return saved;
}

bool AccountManager::editAccounts(const std::function<bool(QJsonArray &)> &edit)
{
    const auto fail = [this](const QString &e) { emit errorOccurred(e); return false; };
    const QString path = m_model->dataDir() + "/accounts.json";
    QFile file(path);
    if (!file.open(QIODevice::ReadOnly)) return fail("Cannot read the account file.");
    const QByteArray original = file.readAll(); file.close();
    QJsonParseError parse;
    const auto document = QJsonDocument::fromJson(original, &parse);
    auto root = document.object();
    if (parse.error != QJsonParseError::NoError || !root.value("accounts").isArray()) return fail("Cannot read the account list.");
    QJsonArray accounts = root.value("accounts").toArray();
    if (!edit(accounts)) return false;
    root.insert("accounts", accounts);
    // Prism may have refreshed tokens meanwhile; never overwrite a file that changed under us.
    QFile check(path);
    if (!check.open(QIODevice::ReadOnly) || check.readAll() != original) return fail("Accounts changed while saving. Try again.");
    check.close();
    const QByteArray bytes = QJsonDocument(root).toJson();
    QSaveFile output(path);
    if (!output.open(QIODevice::WriteOnly) || output.write(bytes) != bytes.size() || !output.commit()) return fail("Cannot save the account list.");
    m_model->reload();
    return true;
}

QVariantList AccountManager::savedSkins() const
{
    QVariantList skins;
    const QDir dir(m_skinsDir);
    for (const QFileInfo &file : dir.entryInfoList({"*.png"}, QDir::Files, QDir::Time)) {
        // Library names are "<hash>-<original name>.png".
        const QString name = file.completeBaseName().section('-', 1);
        skins.append(QVariantMap{{"file", file.fileName()}, {"name", name.isEmpty() ? file.completeBaseName() : name},
                                 {"url", QUrl::fromLocalFile(file.absoluteFilePath()).toString()}});
    }
    return skins;
}

QString AccountManager::addSkin(const QUrl &source)
{
    QFile file(source.toLocalFile());
    if (!file.open(QIODevice::ReadOnly) || file.size() > MaxSkinBytes) {
        emit errorOccurred("Choose a skin PNG smaller than 1 MiB.");
        return {};
    }
    const QByteArray bytes = file.readAll();
    const QImage image = QImage::fromData(bytes, "PNG");
    if (image.isNull() || image.width() != 64 || (image.height() != 64 && image.height() != 32)) {
        emit errorOccurred("Minecraft skins are 64×64 or 64×32 PNG images.");
        return {};
    }
    QString base = QFileInfo(file.fileName()).completeBaseName();
    base.replace(QRegularExpression("[^A-Za-z0-9 _.()]+"), "_");
    base = base.left(48).trimmed();
    const QString hash = QString::fromLatin1(QCryptographicHash::hash(bytes, QCryptographicHash::Sha1).toHex().left(10));
    QDir dir(m_skinsDir);
    // The same picture is stored once, whatever it was called.
    for (const QString &existing : dir.entryList({hash + "-*.png"}, QDir::Files)) return existing;
    const QString name = hash + "-" + (base.isEmpty() ? QStringLiteral("skin") : base) + ".png";
    QSaveFile output(dir.filePath(name));
    if (!dir.mkpath(".") || !output.open(QIODevice::WriteOnly) || output.write(bytes) != bytes.size() || !output.commit()) {
        emit errorOccurred("Cannot save the skin to Prismarine's library.");
        return {};
    }
    emit skinsChanged();
    return name;
}

bool AccountManager::removeSkin(const QString &fileName)
{
    if (QFileInfo(fileName).fileName() != fileName || !fileName.endsWith(".png")) return false;
    const bool removed = QFile::remove(QDir(m_skinsDir).filePath(fileName));
    if (removed) emit skinsChanged();
    return removed;
}

QString AccountManager::accessToken(const QString &accountId)
{
    QFile file(m_model->dataDir() + "/accounts.json");
    if (!file.open(QIODevice::ReadOnly)) return {};
    for (const auto &value : QJsonDocument::fromJson(file.readAll()).object().value("accounts").toArray()) {
        const auto account = value.toObject();
        if (account.value("profile").toObject().value("id").toString() != accountId) continue;
        const auto minecraft = account.value("ygg").toObject();
        const qint64 expires = minecraft.value("exp").toInteger();
        if (expires > QDateTime::currentSecsSinceEpoch() + 60) return minecraft.value("token").toString();
        emit errorOccurred("This sign-in has expired. Refresh it in Prism, then try again.");
        return {};
    }
    emit errorOccurred("This account is no longer available.");
    return {};
}

void AccountManager::applySkin(const QString &accountId, const QString &fileName, const QString &variant)
{
    if (m_busy) return;
    const QString model = variant.compare("slim", Qt::CaseInsensitive) == 0 ? QStringLiteral("slim") : QStringLiteral("classic");
    QByteArray bytes;
    QString currentUrl;
    if (!fileName.isEmpty()) {
        QFile file(QDir(m_skinsDir).filePath(QFileInfo(fileName).fileName()));
        if (!file.open(QIODevice::ReadOnly) || (bytes = file.readAll()).isEmpty()) {
            emit errorOccurred("This skin is no longer in the library.");
            return;
        }
    } else {
        for (const QVariant &account : m_model->accounts())
            if (account.toMap().value("id") == accountId) currentUrl = account.toMap().value("skinUrl").toString();
        if (!currentUrl.startsWith("https://")) {
            emit errorOccurred("Choose a skin to apply.");
            return;
        }
    }
    const QString token = accessToken(accountId);
    if (token.isEmpty()) return;
    QNetworkRequest request(QUrl(m_apiRoot.toString() + "/minecraft/profile/skins"));
    request.setRawHeader("Authorization", "Bearer " + token.toUtf8());
    request.setTransferTimeout(30000);
    QNetworkReply *reply = nullptr;
    if (!bytes.isEmpty()) {
        auto *form = new QHttpMultiPart(QHttpMultiPart::FormDataType);
        QHttpPart variantPart;
        variantPart.setHeader(QNetworkRequest::ContentDispositionHeader, R"(form-data; name="variant")");
        variantPart.setBody(model.toUtf8());
        QHttpPart filePart;
        filePart.setHeader(QNetworkRequest::ContentTypeHeader, "image/png");
        filePart.setHeader(QNetworkRequest::ContentDispositionHeader, R"(form-data; name="file"; filename="skin.png")");
        filePart.setBody(bytes);
        form->append(variantPart);
        form->append(filePart);
        reply = m_network.post(request, form);
        form->setParent(reply);
    } else {
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        reply = m_network.post(request, QJsonDocument(QJsonObject{{"variant", model}, {"url", currentUrl}}).toJson(QJsonDocument::Compact));
    }
    send(accountId, reply, "Skin updated", bytes);
}

void AccountManager::setCape(const QString &accountId, const QString &capeId)
{
    if (m_busy) return;
    const QString token = accessToken(accountId);
    if (token.isEmpty()) return;
    QNetworkRequest request(QUrl(m_apiRoot.toString() + "/minecraft/profile/capes/active"));
    request.setRawHeader("Authorization", "Bearer " + token.toUtf8());
    request.setTransferTimeout(30000);
    QNetworkReply *reply = nullptr;
    if (capeId.isEmpty()) reply = m_network.deleteResource(request);
    else {
        request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
        reply = m_network.put(request, QJsonDocument(QJsonObject{{"capeId", capeId}}).toJson(QJsonDocument::Compact));
    }
    send(accountId, reply, capeId.isEmpty() ? "Cape hidden" : "Cape updated", {});
}

void AccountManager::send(const QString &accountId, QNetworkReply *reply, const QString &done, const QByteArray &uploadedSkin)
{
    m_busy = true;
    emit busyChanged();
    connect(reply, &QNetworkReply::finished, this, [this, accountId, reply, done, uploadedSkin] {
        m_busy = false;
        emit busyChanged();
        const int status = reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt();
        const QJsonObject profile = QJsonDocument::fromJson(reply->readAll()).object();
        reply->deleteLater();
        if (status == 401) { emit errorOccurred("Minecraft rejected the sign-in. Refresh it in Prism, then try again."); return; }
        if (reply->error() != QNetworkReply::NoError || profile.value("id").toString().isEmpty()) {
            emit errorOccurred("Minecraft did not accept the change. Try again later.");
            return;
        }
        // Mirror the new profile into Prism's cached copy so both launchers show it immediately.
        QJsonObject activeSkin;
        for (const auto &skin : profile.value("skins").toArray())
            if (skin.toObject().value("state") == "ACTIVE") activeSkin = skin.toObject();
        QString activeCape;
        for (const auto &cape : profile.value("capes").toArray())
            if (cape.toObject().value("state") == "ACTIVE") activeCape = cape.toObject().value("id").toString();
        editAccounts([&](QJsonArray &accounts) {
            for (qsizetype i = 0; i < accounts.size(); ++i) {
                auto account = accounts[i].toObject();
                auto cached = account.value("profile").toObject();
                if (cached.value("id").toString() != accountId) continue;
                if (!activeSkin.isEmpty()) {
                    auto skin = cached.value("skin").toObject();
                    const bool sameTexture = skin.value("url") == activeSkin.value("url");
                    skin.insert("id", activeSkin.value("id"));
                    skin.insert("url", activeSkin.value("url"));
                    skin.insert("variant", activeSkin.value("variant"));
                    if (!uploadedSkin.isEmpty()) skin.insert("data", QString::fromLatin1(uploadedSkin.toBase64()));
                    else if (!sameTexture) skin.remove("data");
                    cached.insert("skin", skin);
                }
                cached.insert("cape", activeCape);
                account.insert("profile", cached);
                accounts[i] = account;
                return true;
            }
            return false;
        });
        emit profileUpdated(done);
    });
}
