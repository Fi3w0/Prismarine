#pragma once
#include <QByteArray>
#include <QString>

// Thin OpenSSL wrappers for the social layer: Ed25519 identities, and the RSA checks that
// prove a Minecraft account through Mojang's player certificates.
namespace Crypto {
struct KeyPair { QByteArray privateSeed, publicKey; }; // raw 32-byte Ed25519 values

KeyPair generateEd25519();
QByteArray publicFromSeed(const QByteArray &seed);
QByteArray signEd25519(const QByteArray &seed, const QByteArray &message);
bool verifyEd25519(const QByteArray &publicKey, const QByteArray &message, const QByteArray &signature);

// RSA keys arrive as DER (PKCS#8 private, X.509 SubjectPublicKeyInfo public), possibly wrapped in PEM.
QByteArray derFromPem(const QString &pem);
QByteArray signRsaSha256(const QByteArray &privateDer, const QByteArray &message);
bool verifyRsa(const QByteArray &publicDer, const QByteArray &message, const QByteArray &signature, bool sha1);

QString base64Url(const QByteArray &bytes);
QByteArray fromBase64Url(const QString &text);
// 128-bit comparison code. Trust is always indexed by the full public key.
QString fingerprint(const QByteArray &publicKey);
void clearSecret(QByteArray &bytes);
}
