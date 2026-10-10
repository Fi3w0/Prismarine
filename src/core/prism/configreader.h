#pragma once
#include <QHash>
#include <QString>

namespace Prism {
QHash<QString, QString> readConfig(const QString &file);
}
