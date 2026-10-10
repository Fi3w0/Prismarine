#pragma once
#include <QJsonObject>
#include <QByteArray>
namespace CurseForge {
int loaderId(const QString &loader);
QJsonObject version(const QJsonObject &file);
quint32 fingerprint(const QByteArray &bytes);
}
