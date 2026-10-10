#pragma once
#include <QObject>
#include <QVariantMap>

// Prism's Network/Proxy and API settings in prismlauncher.cfg. Prismarine also routes
// its own requests through the same proxy. Secrets are write-only: QML sees only
// whether a password or token is set.
class NetworkSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap values READ values NOTIFY changed)
public:
    explicit NetworkSettings(const QString &dataDir, QObject *parent = nullptr);
    QVariantMap values() const { return m_values; }
    Q_INVOKABLE void load();
    // Keys as in values(); "proxyPass", "modrinthToken" and "flameKey" set a secret,
    // "clearProxyPass", "clearModrinthToken" and "clearFlameKey" remove one.
    Q_INVOKABLE bool save(const QVariantMap &values);
    static void applyApplicationProxy(const QString &dataDir);
signals:
    void changed();
    void saved();
    void errorOccurred(const QString &message);
private:
    QString m_dataDir;
    QVariantMap m_values;
};
