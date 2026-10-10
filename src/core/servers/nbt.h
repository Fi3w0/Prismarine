#pragma once
#include <QByteArray>
#include <QList>
#include <QPair>
#include <QString>
#include <QVariant>

// Minimal uncompressed NBT, enough to edit servers.dat while keeping every unknown field.
namespace Nbt {
enum Type : quint8 { End, Byte, Short, Int, Long, Float, Double, ByteArray, String, List, Compound, IntArray, LongArray };

struct Tag {
    Type type = End;
    QVariant value;                        // Byte..Double and String
    QByteArray bytes;                      // ByteArray
    QList<qint64> numbers;                 // IntArray and LongArray
    Type listType = End;
    QList<Tag> items;                      // List
    QList<QPair<QString, Tag>> children;   // Compound, in file order

    const Tag *child(const QString &name) const;
    Tag *child(const QString &name);
    QString string(const QString &name) const;
    void setString(const QString &name, const QString &text);
    static Tag makeString(const QString &text);
    static Tag makeByte(qint8 value);
};

// Returns false for malformed or oversized input; the root must be a named compound.
bool read(const QByteArray &data, Tag *root, QString *rootName = nullptr);
QByteArray write(const Tag &root, const QString &rootName = {});
}
