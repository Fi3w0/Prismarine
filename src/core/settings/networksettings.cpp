#include "networksettings.h"
#include "../prism/configreader.h"
#include "../prism/configwriter.h"
#include <QNetworkProxy>
#include <QNetworkProxyFactory>
#include <QUrl>

namespace {
struct Field { const char *key, *prism; const char *fallback; };
// Values Prism uses when a key is absent.
const Field fields[] = {
    {"proxyType", "ProxyType", "None"}, {"proxyAddr", "ProxyAddr", "127.0.0.1"}, {"proxyPort", "ProxyPort", "8080"},
    {"proxyUser", "ProxyUser", ""}, {"concurrentDownloads", "NumberOfConcurrentDownloads", "6"},
    {"concurrentTasks", "NumberOfConcurrentTasks", "10"}, {"retries", "NumberOfManualRetries", "1"},
    {"timeout", "RequestTimeout", "60"}, {"userAgent", "UserAgentOverride", ""}, {"metaUrl", "MetaURLOverride", ""},
    {"resourceUrl", "ResourceURLOverride", ""}, {"msaClientId", "MSAClientIDOverride", ""}, {"technicClientId", "TechnicClientID", ""},
};
struct Secret { const char *key, *clear, *has, *prism; };
const Secret secrets[] = {
    {"proxyPass", "clearProxyPass", "hasProxyPass", "ProxyPass"},
    {"modrinthToken", "clearModrinthToken", "hasModrinthToken", "ModrinthToken"},
    {"flameKey", "clearFlameKey", "hasFlameKey", "FlameKeyOverride"},
};
struct Range { const char *key; int minimum, maximum; };
const Range ranges[] = {{"proxyPort", 1, 65535}, {"concurrentDownloads", 1, 64}, {"concurrentTasks", 1, 64}, {"retries", 0, 10}, {"timeout", 1, 600}};
}

NetworkSettings::NetworkSettings(const QString &dataDir, QObject *parent) : QObject(parent), m_dataDir(dataDir)
{
    load();
}

void NetworkSettings::load()
{
    const auto config = Prism::readConfig(m_dataDir + "/prismlauncher.cfg");
    m_values.clear();
    for (const auto &field : fields) m_values.insert(field.key, config.value(field.prism, field.fallback));
    for (const auto &secret : secrets) m_values.insert(secret.has, !config.value(secret.prism).isEmpty());
    emit changed();
}

bool NetworkSettings::save(const QVariantMap &values)
{
    const auto fail = [this](const QString &message) { emit errorOccurred(message); return false; };
    QVariantMap updates;
    for (const auto &field : fields) {
        if (!values.contains(field.key)) continue;
        const QString value = values.value(field.key).toString().trimmed();
        if (value.contains('\n') || value.size() > 2048) return fail("Settings must be on a single line.");
        updates.insert(field.prism, value);
    }
    if (updates.contains("ProxyType") && !QStringList{"None", "Default", "SOCKS5", "HTTP"}.contains(updates.value("ProxyType").toString()))
        return fail("Choose a proxy type.");
    for (const auto &range : ranges) {
        if (!values.contains(range.key)) continue;
        bool ok = false;
        const int number = values.value(range.key).toString().toInt(&ok);
        if (!ok || number < range.minimum || number > range.maximum)
            return fail(QString("%1 must be between %2 and %3.").arg(QString(range.key) == "proxyPort" ? "The proxy port" : QString(range.key) == "timeout" ? "The timeout" : "This value").arg(range.minimum).arg(range.maximum));
    }
    for (const char *key : {"MetaURLOverride", "ResourceURLOverride"}) {
        const QString url = updates.value(key).toString();
        const QUrl parsed(url, QUrl::StrictMode);
        if (!url.isEmpty() && (!parsed.isValid() || (parsed.scheme() != "https" && parsed.scheme() != "http") || parsed.host().isEmpty()))
            return fail("Server overrides must be http:// or https:// addresses.");
    }
    for (const auto &secret : secrets) {
        if (values.value(secret.clear).toBool()) updates.insert(secret.prism, "");
        else if (!values.value(secret.key).toString().isEmpty()) updates.insert(secret.prism, values.value(secret.key).toString().trimmed());
    }
    QString error;
    if (!updates.isEmpty() && !Prism::writeConfig(m_dataDir + "/prismlauncher.cfg", updates, &error, false)) return fail(error);
    applyApplicationProxy(m_dataDir);
    load();
    emit saved();
    return true;
}

void NetworkSettings::applyApplicationProxy(const QString &dataDir)
{
    const auto config = Prism::readConfig(dataDir + "/prismlauncher.cfg");
    const QString type = config.value("ProxyType", "None");
    QNetworkProxyFactory::setUseSystemConfiguration(type == "Default");
    if (type == "Default") return;
    if (type != "SOCKS5" && type != "HTTP") { QNetworkProxy::setApplicationProxy(QNetworkProxy::NoProxy); return; }
    QNetworkProxy proxy(type == "SOCKS5" ? QNetworkProxy::Socks5Proxy : QNetworkProxy::HttpProxy,
                        config.value("ProxyAddr", "127.0.0.1"), quint16(config.value("ProxyPort", "8080").toUInt()),
                        config.value("ProxyUser"), config.value("ProxyPass"));
    QNetworkProxy::setApplicationProxy(proxy);
}
