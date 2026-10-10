#pragma once
#include <QObject>
#include <QVariantList>
#include "instancemodel.h"

// Experimental, off by default: plays one instance with several accounts at once.
// Prism runs one process per instance, so each extra account gets its own copy
// ("<source>.alt-<account>") that is re-synced from the source before every launch.
// Mods and packs are hard links (no extra space), config is copied, worlds are never
// shared. The source instance is only ever read.
class AltLaunch : public QObject {
    Q_OBJECT
public:
    explicit AltLaunch(InstanceModel *model, QObject *parent = nullptr) : QObject(parent), m_model(model) {}
    // [{altId, account, name}] for one source instance.
    Q_INVOKABLE QVariantList altsFor(const QString &sourceId) const;
    // Creates or refreshes the copy, then asks Prism to launch it with that account.
    Q_INVOKABLE bool launchAs(const QString &sourceId, const QString &account);
    // Deletes a copy (to the trash). Only folders carrying the alt marker are accepted.
    Q_INVOKABLE bool removeAlt(const QString &altId);

    static QString altId(const QString &sourceId, const QString &account);
    // Brings `altPath` up to date with `sourcePath`; creates it when missing.
    static bool sync(const QString &sourcePath, const QString &altPath, const QString &sourceId,
                     const QString &account, const QString &accountId, QString *error);
signals:
    void launched(const QString &altId, const QString &account);
    void errorOccurred(const QString &message);
private:
    InstanceModel *m_model;
};
