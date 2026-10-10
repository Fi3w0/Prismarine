#pragma once
#include <QObject>
#include <QJsonArray>
#include <QNetworkAccessManager>
#include <QUrl>
#include <functional>
#include "../library/instancemodel.h"

// Edits Prism's account file without exposing credentials to QML, and changes skins and capes
// through the Minecraft profile API using the token Prism already stored.
class AccountManager : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList savedSkins READ savedSkins NOTIFY skinsChanged)
    Q_PROPERTY(bool busy READ busy NOTIFY busyChanged)
public:
    explicit AccountManager(InstanceModel *model, QObject *parent = nullptr,
                            const QUrl &apiRoot = QUrl("https://api.minecraftservices.com"), const QString &skinsDir = {});
    Q_INVOKABLE bool setDefault(const QString &id);
    Q_INVOKABLE bool remove(const QString &id);

    QVariantList savedSkins() const;
    bool busy() const { return m_busy; }
    // Copies a 64×64 or 64×32 PNG into Prismarine's skin library; returns its library file name.
    Q_INVOKABLE QString addSkin(const QUrl &file);
    Q_INVOKABLE bool removeSkin(const QString &fileName);
    // Uploads a library skin, or re-applies the current texture with a new arm model when fileName is empty.
    Q_INVOKABLE void applySkin(const QString &accountId, const QString &fileName, const QString &variant);
    // An empty capeId hides the cape.
    Q_INVOKABLE void setCape(const QString &accountId, const QString &capeId);
signals:
    void errorOccurred(const QString &message);
    void skinsChanged();
    void busyChanged();
    void profileUpdated(const QString &message);
private:
    friend class SocialManager; // C++ only; credentials never enter QML or social documents.
    bool update(const QString &id, bool remove);
    bool editAccounts(const std::function<bool(QJsonArray &accounts)> &edit);
    QString accessToken(const QString &accountId);
    void send(const QString &accountId, class QNetworkReply *reply, const QString &done, const QByteArray &uploadedSkin);
    InstanceModel *m_model;
    QUrl m_apiRoot;
    QString m_skinsDir;
    QNetworkAccessManager m_network;
    bool m_busy = false;
};
