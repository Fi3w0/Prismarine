#pragma once
#include <QObject>
#include <QVariantMap>
#include "../library/instancemodel.h"

class LaunchSettings : public QObject {
    Q_OBJECT
    Q_PROPERTY(QVariantMap values READ values NOTIFY changed)
    Q_PROPERTY(QString instanceId READ instanceId NOTIFY changed)
public:
    explicit LaunchSettings(InstanceModel *model, QObject *parent = nullptr);
    QVariantMap values() const { return m_values; }
    QString instanceId() const { return m_id; }
    Q_INVOKABLE void load(const QString &id = {});
    Q_INVOKABLE bool save(const QVariantMap &values);
signals:
    void changed();
    void errorOccurred(const QString &message);
private:
    InstanceModel *m_model;
    QString m_id;
    QVariantMap m_values;
    QByteArray m_baseline;
};
