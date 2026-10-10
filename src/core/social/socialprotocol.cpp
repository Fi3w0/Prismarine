#include "socialprotocol.h"
#include "crypto.h"
#include <QDataStream>
#include <QDateTime>
#include <QHostAddress>
#include <QJsonArray>
#include <QJsonDocument>
#include <QRegularExpression>
#include <QSet>
#include <QUuid>

namespace SocialProtocol {
namespace {
const QByteArray EnvelopeDomain("Prismarine signed document v1\n");
const QByteArray LinkDomain("Prismarine Minecraft identity link v1\n");
qint64 expiry(const QJsonObject &link) {
    return QDateTime::fromString(link.value("expiresAt").toString(), Qt::ISODateWithMs).toMSecsSinceEpoch();
}
}
QByteArray seal(const QJsonObject &payload, const QByteArray &seed)
{
    const QByteArray bytes = QJsonDocument(payload).toJson(QJsonDocument::Compact);
    const QByteArray signature = Crypto::signEd25519(seed, EnvelopeDomain + bytes);
    if (signature.isEmpty()) return {};
    const QByteArray result = QJsonDocument(QJsonObject{{"version", 1}, {"publicKey", Crypto::base64Url(Crypto::publicFromSeed(seed))},
        {"payload", Crypto::base64Url(bytes)}, {"signature", Crypto::base64Url(signature)}}).toJson(QJsonDocument::Compact);
    return result.size() <= MaxDocument ? result : QByteArray();
}
Verified open(const QByteArray &document, const QString &type)
{
    const auto fail = [](const QString &message) { return Verified{{}, {}, message}; };
    if (document.isEmpty() || document.size() > MaxDocument) return fail("This social file is empty or too large.");
    QJsonParseError parse;
    const auto envelope = QJsonDocument::fromJson(document, &parse).object();
    if (parse.error != QJsonParseError::NoError || envelope.size() != 4 || envelope.value("version").toInt() != 1)
        return fail("Unsupported social file format.");
    const QByteArray key = Crypto::fromBase64Url(envelope.value("publicKey").toString());
    const QByteArray payload = Crypto::fromBase64Url(envelope.value("payload").toString());
    const QByteArray signature = Crypto::fromBase64Url(envelope.value("signature").toString());
    if (!Crypto::verifyEd25519(key, EnvelopeDomain + payload, signature)) return fail("The signature does not match. This file may have been changed.");
    const auto object = QJsonDocument::fromJson(payload, &parse).object();
    if (parse.error != QJsonParseError::NoError || object.value("type").toString() != type)
        return fail("This is not a Prismarine " + type + " file.");
    return {object, key, {}};
}
QString normalizedUuid(const QString &uuid)
{
    static const QRegularExpression pattern("^(?:[0-9a-fA-F]{32}|[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12})$");
    if (!pattern.match(uuid).hasMatch()) return {};
    QString normalized = uuid.toLower(); normalized.remove('-');
    return normalized == QString(32, '0') ? QString() : normalized;
}
QByteArray certificateMessage(const QString &uuid, qint64 expires, const QByteArray &publicDer)
{
    const QString normalized = normalizedUuid(uuid);
    if (normalized.isEmpty()) return {};
    QByteArray result = QByteArray::fromHex(normalized.toLatin1());
    QByteArray timestamp;
    QDataStream stream(&timestamp, QIODevice::WriteOnly);
    stream.setByteOrder(QDataStream::BigEndian); stream << expires;
    return result + timestamp + publicDer;
}
QByteArray linkMessage(const QByteArray &identity, const QString &uuid, qint64 expires)
{
    return LinkDomain + identity + certificateMessage(uuid, expires, {});
}
QString verifyLink(const QJsonObject &link, const QByteArray &identity, const QList<QByteArray> &roots, qint64 now)
{
    const QString uuid = normalizedUuid(link.value("uuid").toString());
    const qint64 expires = expiry(link);
    const QByteArray key = Crypto::fromBase64Url(link.value("publicKey").toString());
    const QByteArray cert = Crypto::fromBase64Url(link.value("certificate").toString());
    if (identity.size() != 32 || uuid.isEmpty() || expires <= 0 || key.isEmpty() || key.size() > 4096 || cert.size() > 1024)
        return "Invalid Minecraft account proof.";
    if (expires <= now) return "This Minecraft account proof has expired. Ask for a refreshed friend card.";
    const QByteArray message = certificateMessage(uuid, expires, key);
    bool certified = false;
    for (const QByteArray &root : roots) if (Crypto::verifyRsa(root, message, cert, true)) { certified = true; break; }
    if (!certified) return "Mojang did not certify this Minecraft account key.";
    if (!Crypto::verifyRsa(key, linkMessage(identity, uuid, expires), Crypto::fromBase64Url(link.value("signature").toString()), false))
        return "This Minecraft account did not sign a link to this Prismarine identity.";
    if (!validLabel(link.value("name").toString(), 16)) return "Invalid Minecraft display name.";
    return {};
}
bool validLabel(const QString &name, int maxLength)
{
    if (name.trimmed().isEmpty() || name.size() > maxLength) return false;
    for (const QChar c : name) if (!c.isPrint() || c.category() == QChar::Other_Format) return false;
    return true;
}
QString verifyCard(const Verified &card, const QList<QByteArray> &roots, qint64 now, bool allowExpired)
{
    if (!card) return card.error;
    if (!validLabel(card.payload.value("name").toString()) || !card.payload.value("accounts").isArray()) return "Invalid friend card.";
    const auto accounts = card.payload.value("accounts").toArray();
    if (accounts.size() > MaxAccounts) return "Too many Minecraft accounts in this friend card.";
    QSet<QString> uuids;
    for (const auto &value : accounts) {
        const auto link = value.toObject();
        const QString id = normalizedUuid(link.value("uuid").toString());
        if (uuids.contains(id)) return "Repeated Minecraft account in this friend card.";
        uuids.insert(id);
        // Saved contacts retain key continuity; an expired certificate is never shown as current proof.
        const auto error = verifyLink(link, card.publicKey, roots, allowExpired ? 0 : now);
        if (!error.isEmpty()) return error;
    }
    return {};
}
bool validServer(const QString &address)
{
    if (address.size() > 255) return false;
    static const QRegularExpression pattern("^(?:([A-Za-z0-9][A-Za-z0-9._-]{0,252})|\\[([0-9A-Fa-f:.]+)\\])(?::([0-9]{1,5}))?$");
    const auto match = pattern.match(address);
    if (!match.hasMatch()) return false;
    if (!match.captured(2).isEmpty() && QHostAddress(match.captured(2)).protocol() != QAbstractSocket::IPv6Protocol) return false;
    const QString port = match.captured(3);
    return port.isEmpty() || (port.toInt() > 0 && port.toInt() <= 65535);
}
QString verifyInvite(const Verified &invite, const QByteArray &recipient, qint64 now)
{
    if (!invite) return invite.error;
    const auto p = invite.payload;
    if (Crypto::fromBase64Url(p.value("recipient").toString()) != recipient) return "This invite is addressed to another Prismarine identity.";
    const qint64 issued = p.value("issued").toInteger(), expires = p.value("expires").toInteger();
    if (issued <= 0 || issued > now + 60000 || expires <= now || expires <= issued || expires - issued > 7LL * 86400000)
        return "This invite has expired or its dates are invalid.";
    if (QUuid(p.value("id").toString()).isNull() || !validLabel(p.value("title").toString())) return "Invalid invite.";
    const QString server = p.value("server").toString();
    const auto pack = p.value("pack").toObject();
    if ((!server.isEmpty() && !validServer(server)) || (server.isEmpty() && pack.isEmpty())) return "Invalid server or missing pack in invite.";
    if (!pack.isEmpty()) {
        const QString name = pack.value("name").toString();
        static const QRegularExpression hash("^[0-9a-f]{64}$");
        if (!validLabel(name, 128) || name.contains('/') || name.contains('\\')
            || (!name.endsWith(".mrpack", Qt::CaseInsensitive) && !name.endsWith(".zip", Qt::CaseInsensitive))
            || !hash.match(pack.value("sha256").toString()).hasMatch()) return "Invalid pack reference in invite.";
    }
    return {};
}
}
