#include "accountreader.h"
#include "../mods/contentart.h"
#include <QDateTime>
#include <QFile>
#include <QJsonArray>
#include <QJsonObject>
#include <QJsonDocument>

QVariantList Prism::readAccounts(const QString &dataDir)
{
    QFile file(dataDir + "/accounts.json");
    if (!file.open(QIODevice::ReadOnly)) return {};
    QVariantList result;
    for (const auto &value : QJsonDocument::fromJson(file.readAll()).object().value("accounts").toArray()) {
        const auto account = value.toObject();
        const auto profile = account.value("profile").toObject();
        const auto skin = profile.value("skin").toObject();
        const QString cached = ContentArt::fromBytes(QByteArray::fromBase64(skin.value("data").toString().toLatin1()));
        const QString name = profile.value("name").toString();
        if (!name.isEmpty())
            result.append(QVariantMap{{"name", name}, {"id", profile.value("id").toString()},
                                      {"active", account.value("active").toBool()},
                                      {"type", account.value("type").toString()},
                                      {"skin", cached.isEmpty() ? skin.value("url").toString() : cached},
                                      {"skinUrl", skin.value("url").toString()},
                                      {"skinVariant", skin.value("variant").toString("CLASSIC")},
                                      {"cape", profile.value("cape").toString()},
                                      // Only the expiry is exposed; tokens never leave the core library.
                                      {"signedIn", account.value("ygg").toObject().value("exp").toInteger() > QDateTime::currentSecsSinceEpoch()},
                                      {"capes", profile.value("capes").toArray().toVariantList()}});
    }
    return result;
}

