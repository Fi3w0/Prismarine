#include "socialmanager.h"
#include "crypto.h"
#include "../accounts/accountmanager.h"
#include <QDateTime>
#include <QJsonDocument>
#include <QNetworkReply>
#include <QNetworkRequest>

void SocialManager::linkAccount(const QString &accountId)
{
    if (!writable() || !m_accounts) return;
    const QString uuid = SocialProtocol::normalizedUuid(accountId);
    if (uuid.isEmpty()) { fail("Choose a valid Minecraft Java account."); return; }
    QString name;
    for (const auto &value : m_accounts->m_model->accounts()) {
        const auto account = value.toMap();
        if (SocialProtocol::normalizedUuid(account.value("id").toString()) == uuid && account.value("type").toString() == "MSA")
            name = account.value("name").toString();
    }
    if (!SocialProtocol::validLabel(name, 16)) { fail("Sign in to a Microsoft Minecraft account through Prism first."); return; }
    bool replacing = false;
    for (const auto &value : m_links) if (value.toObject().value("uuid").toString() == uuid) replacing = true;
    if (!replacing && m_links.size() >= SocialProtocol::MaxAccounts) { fail("You can link up to 16 Minecraft accounts."); return; }
    QString token = m_accounts->accessToken(accountId);
    if (token.isEmpty()) { fail("Refresh this Minecraft sign-in in Prism, then try linking again."); return; }
    QUrl endpoint = m_api; endpoint.setPath("/player/certificates"); endpoint.setQuery({}); endpoint.setFragment({});
    QNetworkRequest request(endpoint);
    request.setAttribute(QNetworkRequest::RedirectPolicyAttribute, QNetworkRequest::ManualRedirectPolicy);
    request.setTransferTimeout(20000);
    request.setRawHeader("Authorization", "Bearer " + token.toUtf8()); token.fill(QChar('\0')); token.clear();
    request.setHeader(QNetworkRequest::ContentTypeHeader, "application/json");
    m_busy = true; emit changed();
    const auto generation = m_generation;
    auto *reply = m_network.post(request, QByteArray()); m_reply = reply;
    reply->setReadBufferSize(65537);
    auto bytes = std::make_shared<QByteArray>();
    connect(reply, &QIODevice::readyRead, this, [reply, bytes] {
        *bytes += reply->readAll();
        if (bytes->size() > 65536) reply->abort();
    });
    connect(reply, &QNetworkReply::finished, this, [this, reply, bytes, generation, uuid, name] {
        reply->deleteLater();
        if (generation != m_generation) { Crypto::clearSecret(*bytes); return; }
        m_reply = nullptr; m_busy = false; emit changed();
        *bytes += reply->readAll();
        if (reply->error() != QNetworkReply::NoError || reply->attribute(QNetworkRequest::HttpStatusCodeAttribute).toInt() != 200 || bytes->size() > 65536) {
            Crypto::clearSecret(*bytes);
            fail("Minecraft could not issue an account proof. Refresh the sign-in in Prism and check your connection. Your existing links were kept."); return;
        }
        auto certificate = QJsonDocument::fromJson(*bytes).object(); Crypto::clearSecret(*bytes);
        auto pair = certificate.take("keyPair").toObject();
        QByteArray privateKey = Crypto::derFromPem(pair.take("privateKey").toString());
        const QByteArray publicKey = Crypto::derFromPem(pair.value("publicKey").toString());
        const auto expires = QDateTime::fromString(certificate.value("expiresAt").toString(), Qt::ISODateWithMs);
        const QByteArray authoritySignature = QByteArray::fromBase64(certificate.value("publicKeySignatureV2").toString().toLatin1(), QByteArray::AbortOnBase64DecodingErrors);
        const auto signature = Crypto::signRsaSha256(privateKey, SocialProtocol::linkMessage(m_publicKey, uuid, expires.toMSecsSinceEpoch()));
        Crypto::clearSecret(privateKey);
        QJsonObject link{{"uuid", uuid}, {"name", name}, {"expiresAt", expires.toUTC().toString(Qt::ISODateWithMs)},
            {"publicKey", Crypto::base64Url(publicKey)}, {"certificate", Crypto::base64Url(authoritySignature)}, {"signature", Crypto::base64Url(signature)}};
        const auto error = SocialProtocol::verifyLink(link, m_publicKey, m_roots, QDateTime::currentMSecsSinceEpoch());
        if (!error.isEmpty()) { fail(error); return; }
        const auto previous = m_links;
        for (int i = m_links.size() - 1; i >= 0; --i) if (m_links[i].toObject().value("uuid").toString() == uuid) m_links.removeAt(i);
        m_links.append(link);
        if (!save()) { m_links = previous; return; }
        emit notice("Minecraft account linked. Export a new friend card to share its current proof.");
    });
}
