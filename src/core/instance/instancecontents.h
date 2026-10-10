#pragma once
#include <QVariantMap>
#include <QVariantList>

struct InstanceContents {
    QVariantMap info;
    QVariantList mods;
    QVariantList screenshots;
    QVariantList files;
};
namespace InstanceContent {
InstanceContents scan(const QString &path, const QString &dataDir, QVariantMap info);
}
