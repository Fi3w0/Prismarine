#pragma once
#include "../library/instance.h"
#include <QHash>
#include <QVector>
namespace Prism {
QVector<Instance> readInstances(const QString &dataDir, const QString &instanceDir, const QHash<QString, QString> &global);
}
