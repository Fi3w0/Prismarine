#include "crypto.h"
#include <QCryptographicHash>
#include <QRegularExpression>
#include <openssl/evp.h>
#include <openssl/rand.h>
#include <openssl/x509.h>
#include <openssl/crypto.h>
#include <memory>

namespace {
using Key = std::unique_ptr<EVP_PKEY, decltype(&EVP_PKEY_free)>;
using Context = std::unique_ptr<EVP_MD_CTX, decltype(&EVP_MD_CTX_free)>;

Key ed25519Private(const QByteArray &seed)
{
    return Key(seed.size() == 32 ? EVP_PKEY_new_raw_private_key(EVP_PKEY_ED25519, nullptr, reinterpret_cast<const unsigned char *>(seed.constData()), 32) : nullptr,
               EVP_PKEY_free);
}
}

namespace Crypto {
KeyPair generateEd25519()
{
    QByteArray seed(32, '\0');
    if (RAND_bytes(reinterpret_cast<unsigned char *>(seed.data()), 32) != 1) return {};
    return {seed, publicFromSeed(seed)};
}

QByteArray publicFromSeed(const QByteArray &seed)
{
    Key key = ed25519Private(seed);
    if (!key) return {};
    QByteArray out(32, '\0');
    size_t length = 32;
    if (EVP_PKEY_get_raw_public_key(key.get(), reinterpret_cast<unsigned char *>(out.data()), &length) != 1 || length != 32) return {};
    return out;
}

QByteArray signEd25519(const QByteArray &seed, const QByteArray &message)
{
    Key key = ed25519Private(seed);
    Context ctx(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!key || !ctx || EVP_DigestSignInit(ctx.get(), nullptr, nullptr, nullptr, key.get()) != 1) return {};
    QByteArray signature(64, '\0');
    size_t length = 64;
    if (EVP_DigestSign(ctx.get(), reinterpret_cast<unsigned char *>(signature.data()), &length,
                       reinterpret_cast<const unsigned char *>(message.constData()), size_t(message.size())) != 1 || length != 64) return {};
    return signature;
}

bool verifyEd25519(const QByteArray &publicKey, const QByteArray &message, const QByteArray &signature)
{
    if (publicKey.size() != 32 || signature.size() != 64) return false;
    Key key(EVP_PKEY_new_raw_public_key(EVP_PKEY_ED25519, nullptr, reinterpret_cast<const unsigned char *>(publicKey.constData()), 32), EVP_PKEY_free);
    Context ctx(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!key || !ctx || EVP_DigestVerifyInit(ctx.get(), nullptr, nullptr, nullptr, key.get()) != 1) return false;
    return EVP_DigestVerify(ctx.get(), reinterpret_cast<const unsigned char *>(signature.constData()), size_t(signature.size()),
                            reinterpret_cast<const unsigned char *>(message.constData()), size_t(message.size())) == 1;
}

QByteArray derFromPem(const QString &pem)
{
    // Mojang labels its keys "RSA PRIVATE KEY"/"RSA PUBLIC KEY" but the bodies are PKCS#8 and X.509; only the body matters.
    QString body = pem;
    body.remove(QRegularExpression(QStringLiteral("-----[A-Z ]+-----")));
    body.remove(QRegularExpression(QStringLiteral("\\s")));
    return QByteArray::fromBase64(body.toLatin1(), QByteArray::AbortOnBase64DecodingErrors);
}

QByteArray signRsaSha256(const QByteArray &privateDer, const QByteArray &message)
{
    const auto *data = reinterpret_cast<const unsigned char *>(privateDer.constData());
    Key key(d2i_AutoPrivateKey(nullptr, &data, long(privateDer.size())), EVP_PKEY_free);
    Context ctx(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!key || data != reinterpret_cast<const unsigned char *>(privateDer.constData()) + privateDer.size()
        || !ctx || EVP_PKEY_get_base_id(key.get()) != EVP_PKEY_RSA || EVP_PKEY_get_bits(key.get()) < 2048
        || EVP_DigestSignInit(ctx.get(), nullptr, EVP_sha256(), nullptr, key.get()) != 1) return {};
    size_t length = 0;
    if (EVP_DigestSign(ctx.get(), nullptr, &length, reinterpret_cast<const unsigned char *>(message.constData()), size_t(message.size())) != 1) return {};
    QByteArray signature(int(length), '\0');
    if (EVP_DigestSign(ctx.get(), reinterpret_cast<unsigned char *>(signature.data()), &length,
                       reinterpret_cast<const unsigned char *>(message.constData()), size_t(message.size())) != 1) return {};
    signature.resize(int(length));
    return signature;
}

bool verifyRsa(const QByteArray &publicDer, const QByteArray &message, const QByteArray &signature, bool sha1)
{
    const auto *data = reinterpret_cast<const unsigned char *>(publicDer.constData());
    Key key(d2i_PUBKEY(nullptr, &data, long(publicDer.size())), EVP_PKEY_free);
    Context ctx(EVP_MD_CTX_new(), EVP_MD_CTX_free);
    if (!key || data != reinterpret_cast<const unsigned char *>(publicDer.constData()) + publicDer.size()
        || !ctx || EVP_PKEY_get_base_id(key.get()) != EVP_PKEY_RSA || EVP_PKEY_get_bits(key.get()) < 2048
        || EVP_DigestVerifyInit(ctx.get(), nullptr, sha1 ? EVP_sha1() : EVP_sha256(), nullptr, key.get()) != 1) return false;
    return EVP_DigestVerify(ctx.get(), reinterpret_cast<const unsigned char *>(signature.constData()), size_t(signature.size()),
                            reinterpret_cast<const unsigned char *>(message.constData()), size_t(message.size())) == 1;
}

QString base64Url(const QByteArray &bytes)
{
    return QString::fromLatin1(bytes.toBase64(QByteArray::Base64UrlEncoding | QByteArray::OmitTrailingEquals));
}

QByteArray fromBase64Url(const QString &text)
{
    static const QRegularExpression alphabet(QStringLiteral("^[A-Za-z0-9_-]*$"));
    if (!alphabet.match(text).hasMatch()) return {};
    const auto result = QByteArray::fromBase64Encoding(text.toLatin1(), QByteArray::Base64UrlEncoding | QByteArray::AbortOnBase64DecodingErrors);
    return result && base64Url(*result) == text ? *result : QByteArray();
}

QString fingerprint(const QByteArray &publicKey)
{
    const QString hex = QString::fromLatin1(QCryptographicHash::hash(publicKey, QCryptographicHash::Sha256).toHex().left(32)).toUpper();
    QStringList parts;
    for (int i = 0; i < hex.size(); i += 4) parts.append(hex.mid(i, 4));
    return parts.join('-');
}

void clearSecret(QByteArray &bytes)
{
    if (!bytes.isEmpty()) OPENSSL_cleanse(bytes.data(), size_t(bytes.size()));
    bytes.clear();
}
}
