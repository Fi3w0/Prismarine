#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QUrl>
#include <QVariantList>

// Prism Launcher's Atom news feed, shown on the home page.
class NewsFeed : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList items READ items NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
public:
    explicit NewsFeed(QObject *parent = nullptr, const QUrl &feed = QUrl("https://prismlauncher.org/feed/feed.xml"));
    QVariantList items() const { return m_items; }
    bool loading() const { return m_loading; }
    QString error() const { return m_error; }
    // Loads once per session; later calls reuse the result unless the last attempt failed.
    Q_INVOKABLE void load();
    static QVariantList parse(const QByteArray &atom, int limit = 4);
signals:
    void changed();
private:
    QUrl m_feed;
    QNetworkAccessManager m_network;
    QVariantList m_items;
    bool m_loading = false, m_loaded = false;
    QString m_error;
};
