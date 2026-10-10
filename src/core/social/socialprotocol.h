#pragma once
#include <QJsonObject>
#include <QList>
#include <QString>

namespace SocialProtocol {
constexpr int MaxDocument = 128 * 1024;
constexpr int MaxAccounts = 16;
struct Verified {
    QJsonObject payload;
    QByteArray publicKey;
    QString error;
    explicit operator bool() const { return error.isEmpty() && !publicKey.isEmpty(); }
};
QByteArray seal(const QJsonObject &payload, const QByteArray &seed);
Verified open(const QByteArray &document, const QString &type);
QByteArray certificateMessage(const QString &uuid, qint64 expires, const QByteArray &publicDer);
QByteArray linkMessage(const QByteArray &identity, const QString &uuid, qint64 expires);
QString verifyLink(const QJsonObject &link, const QByteArray &identity, const QList<QByteArray> &roots, qint64 now);
QString verifyCard(const Verified &card, const QList<QByteArray> &roots, qint64 now, bool allowExpired = false);
QString verifyInvite(const Verified &invite, const QByteArray &recipient, qint64 now);
bool validLabel(const QString &name, int maxLength = 64);
bool validServer(const QString &address);
QString normalizedUuid(const QString &uuid);
}
