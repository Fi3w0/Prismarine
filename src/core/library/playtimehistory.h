#pragma once
#include <QObject>
#include <QDate>
#include <QJsonObject>
#include <QVariantList>

class InstanceModel;

// Prism keeps only a running total per instance. Each time the library loads, any growth since the
// last look is stored as play time on the day of that instance's last launch, so the history covers
// games started from Prism as well as from Prismarine.
class PlaytimeHistory : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantList weeks READ weeks NOTIFY changed)
    Q_PROPERTY(QVariantList topThisMonth READ topThisMonth NOTIFY changed)
    Q_PROPERTY(qint64 thisWeekSecs READ thisWeekSecs NOTIFY changed)
    Q_PROPERTY(int streakDays READ streakDays NOTIFY changed)
    Q_PROPERTY(QString trackedSince READ trackedSince NOTIFY changed)
public:
    explicit PlaytimeHistory(InstanceModel *instances, QObject *parent = nullptr, const QString &file = {});
    // The last 12 weeks, oldest first: {label, start, secs}.
    QVariantList weeks() const { return weeksEnding(QDate::currentDate(), 12); }
    QVariantList weeksEnding(const QDate &today, int count) const;
    QVariantList topThisMonth() const;
    qint64 thisWeekSecs() const;
    int streakDays() const;
    QString trackedSince() const;
    // Compares the library's totals with the last snapshot and stores any new play time.
    Q_INVOKABLE void record();
signals:
    void changed();
private:
    void save() const;
    InstanceModel *m_instances;
    QString m_file;
    QJsonObject m_known;      // instance id -> last seen total seconds
    QList<QJsonObject> m_days; // {id, name, day: "yyyy-MM-dd", secs}
    QDate m_since;
};
