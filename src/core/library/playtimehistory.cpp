#include "playtimehistory.h"
#include "instancemodel.h"
#include <QDateTime>
#include <QDir>
#include <QFile>
#include <QFileInfo>
#include <QJsonArray>
#include <QJsonDocument>
#include <QLocale>
#include <QSaveFile>
#include <QSet>
#include <QStandardPaths>
#include <algorithm>

PlaytimeHistory::PlaytimeHistory(InstanceModel *instances, QObject *parent, const QString &file)
    : QObject(parent), m_instances(instances),
      m_file(file.isEmpty() ? QStandardPaths::writableLocation(QStandardPaths::AppDataLocation) + "/playtime.json" : file)
{
    QFile input(m_file);
    if (input.open(QIODevice::ReadOnly)) {
        const QJsonObject root = QJsonDocument::fromJson(input.readAll()).object();
        m_known = root.value("known").toObject();
        m_since = QDate::fromString(root.value("since").toString(), Qt::ISODate);
        for (const auto &value : root.value("days").toArray()) m_days.append(value.toObject());
    }
    if (m_instances) connect(m_instances, &QAbstractItemModel::modelReset, this, &PlaytimeHistory::record);
    record();
}

void PlaytimeHistory::record()
{
    if (!m_instances) return;
    bool dirty = false;
    if (!m_since.isValid()) { m_since = QDate::currentDate(); dirty = true; }
    for (const QVariant &value : m_instances->allInstances()) {
        const QVariantMap inst = value.toMap();
        const QString id = inst.value("instanceId").toString();
        const qint64 total = inst.value("playedSecs").toLongLong();
        if (id.isEmpty()) continue;
        // The first sighting is a baseline: time played before tracking began is not spread over today.
        if (!m_known.contains(id)) { m_known.insert(id, total); dirty = true; continue; }
        const qint64 before = m_known.value(id).toInteger();
        if (total == before) continue;
        m_known.insert(id, total);
        dirty = true;
        if (total < before) continue; // Prism's counter was reset; adopt the new total.
        const qint64 launch = inst.value("lastLaunchMs").toLongLong();
        const QDate day = launch > 0 ? QDateTime::fromMSecsSinceEpoch(launch).date() : QDate::currentDate();
        const QString key = day.toString(Qt::ISODate);
        auto existing = std::find_if(m_days.begin(), m_days.end(), [&](const QJsonObject &d) { return d.value("id") == id && d.value("day") == key; });
        if (existing != m_days.end()) existing->insert("secs", existing->value("secs").toInteger() + (total - before));
        else m_days.append(QJsonObject{{"id", id}, {"name", inst.value("name").toString()}, {"day", key}, {"secs", total - before}});
    }
    if (dirty) {
        save();
        emit changed();
    }
}

void PlaytimeHistory::save() const
{
    QJsonArray days;
    for (const QJsonObject &day : m_days) days.append(day);
    const QByteArray bytes = QJsonDocument(QJsonObject{{"since", m_since.toString(Qt::ISODate)}, {"known", m_known}, {"days", days}}).toJson(QJsonDocument::Compact);
    QDir().mkpath(QFileInfo(m_file).path());
    QSaveFile output(m_file);
    if (output.open(QIODevice::WriteOnly) && output.write(bytes) == bytes.size()) output.commit();
}

QVariantList PlaytimeHistory::weeksEnding(const QDate &today, int count) const
{
    const QDate thisMonday = today.addDays(1 - today.dayOfWeek());
    QVariantList weeks;
    for (int i = count - 1; i >= 0; --i) {
        const QDate start = thisMonday.addDays(-7 * i), end = start.addDays(7);
        qint64 secs = 0;
        for (const QJsonObject &day : m_days) {
            const QDate date = QDate::fromString(day.value("day").toString(), Qt::ISODate);
            if (date >= start && date < end) secs += day.value("secs").toInteger();
        }
        weeks.append(QVariantMap{{"label", QLocale(QLocale::English).toString(start, "MMM d")}, {"start", start.toString(Qt::ISODate)},
                                 {"secs", secs}, {"tracked", end > m_since}});
    }
    return weeks;
}

qint64 PlaytimeHistory::thisWeekSecs() const
{
    const QVariantList last = weeksEnding(QDate::currentDate(), 1);
    return last.isEmpty() ? 0 : last.first().toMap().value("secs").toLongLong();
}

QVariantList PlaytimeHistory::topThisMonth() const
{
    const QDate today = QDate::currentDate(), start(today.year(), today.month(), 1);
    QMap<QString, QPair<QString, qint64>> totals;
    for (const QJsonObject &day : m_days) {
        if (QDate::fromString(day.value("day").toString(), Qt::ISODate) < start) continue;
        auto &entry = totals[day.value("id").toString()];
        entry.first = day.value("name").toString();
        entry.second += day.value("secs").toInteger();
    }
    QVariantList list;
    for (auto it = totals.begin(); it != totals.end(); ++it) {
        // Prefer the current name if the instance was renamed.
        const QString current = m_instances ? m_instances->getById(it.key()).value("name").toString() : QString();
        list.append(QVariantMap{{"id", it.key()}, {"name", current.isEmpty() ? it.value().first : current}, {"secs", it.value().second}});
    }
    std::sort(list.begin(), list.end(), [](const QVariant &a, const QVariant &b) { return a.toMap().value("secs").toLongLong() > b.toMap().value("secs").toLongLong(); });
    return list.mid(0, 5);
}

int PlaytimeHistory::streakDays() const
{
    QSet<QDate> played;
    for (const QJsonObject &day : m_days)
        if (day.value("secs").toInteger() > 0) played.insert(QDate::fromString(day.value("day").toString(), Qt::ISODate));
    QDate day = QDate::currentDate();
    if (!played.contains(day)) day = day.addDays(-1); // today's session may not have happened yet
    int streak = 0;
    while (played.contains(day)) { ++streak; day = day.addDays(-1); }
    return streak;
}

QString PlaytimeHistory::trackedSince() const
{
    return m_since.isValid() ? QLocale(QLocale::English).toString(m_since, "MMM d, yyyy") : QString();
}
