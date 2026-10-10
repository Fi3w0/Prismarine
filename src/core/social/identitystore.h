#pragma once
#include <QObject>
#include <QByteArray>
#include <functional>

// No fallback to files. Injectable only in C++ for isolated tests.
class IdentityStore : public QObject {
public:
    using ReadDone = std::function<void(QByteArray, bool, QString)>; // seed, not found, error
    using WriteDone = std::function<void(QString)>;
    using QObject::QObject;
    virtual bool available() const = 0;
    virtual void read(const QString &key, ReadDone done) = 0;
    virtual void write(const QString &key, const QByteArray &seed, WriteDone done) = 0;
};
IdentityStore *systemIdentityStore(QObject *parent);
