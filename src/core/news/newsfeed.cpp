#include "newsfeed.h"
#include <QDateTime>
#include <QLocale>
#include <QNetworkReply>
#include <QTextDocumentFragment>
#include <QXmlStreamReader>

NewsFeed::NewsFeed(QObject *parent, const QUrl &feed) : QObject(parent), m_feed(feed) {}

void NewsFeed::load()
{
    if (m_loading || m_loaded) return;
    m_loading = true;
    m_error.clear();
    emit changed();
    QNetworkRequest request(m_feed);
    request.setRawHeader("User-Agent", "Prismarine/0.4.0 (Qt desktop UI)");
    request.setTransferTimeout(15000);
    auto *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply] {
        m_loading = false;
        const QVariantList items = reply->error() == QNetworkReply::NoError ? parse(reply->readAll()) : QVariantList();
        if (items.isEmpty()) m_error = QStringLiteral("News is unavailable right now.");
        else {
            m_items = items;
            m_loaded = true;
        }
        emit changed();
        reply->deleteLater();
    });
}

QVariantList NewsFeed::parse(const QByteArray &atom, int limit)
{
    QVariantList items;
    QXmlStreamReader xml(atom);
    QVariantMap entry;
    bool inEntry = false;
    while (!xml.atEnd() && items.size() < limit) {
        xml.readNext();
        if (xml.isStartElement()) {
            const auto name = xml.name();
            if (name == u"entry") {
                inEntry = true;
                entry.clear();
            } else if (inEntry && name == u"link" && entry.value("url").toString().isEmpty()) {
                const QUrl url(xml.attributes().value("href").toString());
                // Only web links are opened from the home page.
                if (url.scheme() == "https" || url.scheme() == "http") entry["url"] = url.toString();
            } else if (inEntry && (name == u"title" || name == u"summary" || name == u"updated")) {
                const QString key = name.toString();
                QString text = xml.readElementText(QXmlStreamReader::IncludeChildElements).trimmed();
                if (key != "updated") text = QTextDocumentFragment::fromHtml(text).toPlainText().simplified();
                entry[key] = text;
            }
        } else if (xml.isEndElement() && xml.name() == u"entry" && inEntry) {
            inEntry = false;
            if (entry.value("title").toString().isEmpty()) continue;
            const QDateTime updated = QDateTime::fromString(entry.value("updated").toString(), Qt::ISODateWithMs);
            entry["date"] = updated.isValid() ? QLocale(QLocale::English).toString(updated.date(), "MMM d") : QString();
            items.append(entry);
        }
    }
    return items;
}
