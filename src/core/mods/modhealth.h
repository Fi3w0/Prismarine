#pragma once
#include <QObject>
#include <QVariantList>
#include "../library/instancemodel.h"

// Finds problems the loader would report at launch: two copies of a mod, missing
// required dependencies, declared incompatibilities, and mods for another loader.
// Only presence is checked; version ranges are left to the loader.
class ModHealth : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY changed)
    Q_PROPERTY(bool checking READ checking NOTIFY changed)
    Q_PROPERTY(QVariantList issues READ issues NOTIFY changed)
    Q_PROPERTY(int errors READ errors NOTIFY changed)
    Q_PROPERTY(int warnings READ warnings NOTIFY changed)
public:
    explicit ModHealth(InstanceModel *model, QObject *parent = nullptr) : QObject(parent), m_model(model) {}
    QString instanceId() const { return m_id; }
    bool checking() const { return m_checking; }
    QVariantList issues() const { return m_issues; }
    int errors() const;
    int warnings() const;
    Q_INVOKABLE void check(const QString &instanceId);
    Q_INVOKABLE void recheck() { check(m_id); }
    // Each issue: {severity: error|warning, kind, title, detail, files, fixes: [{label, action, value}]}.
    static QVariantList analyze(const QString &modsDir, const QString &loader, const QString &minecraft);
signals:
    void changed();
private:
    InstanceModel *m_model;
    QString m_id;
    QVariantList m_issues;
    bool m_checking = false;
    quint64 m_generation = 0;
};
