#include "displayformat.h"
#include <QDateTime>

namespace Library {
QString formatPlayed(qint64 secs)
{
    if (secs <= 0)
        return QStringLiteral("not played yet");
    const qint64 hours = secs / 3600;
    const qint64 minutes = (secs % 3600) / 60;
    if (hours == 0)
        return QStringLiteral("%1 min").arg(minutes);
    return QStringLiteral("%1 h").arg(hours);
}

QString formatLastPlayed(qint64 ms)
{
    if (ms <= 0)
        return QStringLiteral("never");
    const QDate then = QDateTime::fromMSecsSinceEpoch(ms).date();
    return then.toString(then.year() == QDate::currentDate().year() ? "MMM d" : "MMM d, yyyy");
}

}
