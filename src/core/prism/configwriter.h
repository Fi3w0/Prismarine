#pragma once
#include <QString>
#include <QVariantMap>
namespace Prism {
bool writeConfig(const QString &path, const QVariantMap &updates, QString *error, bool requireExisting = true);
}
