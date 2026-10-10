#pragma once
#include <QObject>
#include <QUrl>
#include <QVariantList>
#include <QVariantMap>
#include "../library/instancemodel.h"

// Recognises files dragged onto the window and copies loose content into an instance.
// Modpacks are only identified here; PackImporter imports them.
class DroppedFiles : public QObject {
    Q_OBJECT
public:
    explicit DroppedFiles(InstanceModel *model, QObject *parent = nullptr) : QObject(parent), m_model(model) {}
    // kind: mod, resourcepack, shader, datapack, modpack, or unknown.
    static QVariantMap inspectFile(const QString &path);
    Q_INVOKABLE QVariantList inspect(const QVariantList &urls) const;
    // Returns {installed, skipped: [{fileName, reason}]}; datapacks need a world.
    Q_INVOKABLE QVariantMap install(const QString &instanceId, const QVariantList &urls, const QString &world = {});
    // Whether a mod's detected loaders can run on an instance's loader.
    Q_INVOKABLE static bool loaderMatches(const QStringList &modLoaders, const QString &instanceLoader);
signals:
    void installed(const QString &instanceId, int count);
    void errorOccurred(const QString &message);
private:
    InstanceModel *m_model;
};
