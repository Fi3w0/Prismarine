#pragma once
#include <QFileInfo>
#include <QVariantMap>
namespace Mods {
QVariantMap readMetadata(const QFileInfo &file);
}
