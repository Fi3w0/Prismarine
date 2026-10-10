#pragma once
#include <QString>
#include <QStringList>
namespace ContentArt {
QString fromBytes(const QByteArray &bytes);
QString fromArchive(const QString &path, const QStringList &names);
QString fromFolder(const QString &path, const QStringList &names);
}
