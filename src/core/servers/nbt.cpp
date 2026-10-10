#include "nbt.h"
#include <QDataStream>
#include <QIODevice>

namespace Nbt {
namespace {
constexpr int MaxDepth = 64;
constexpr qint32 MaxElements = 1 << 20;

// NBT strings are Java "modified UTF-8"; for the text in servers.dat this matches UTF-8.
bool readString(QDataStream &in, QString *text)
{
    quint16 length = 0;
    in >> length;
    QByteArray bytes(length, Qt::Uninitialized);
    if (in.readRawData(bytes.data(), length) != length) return false;
    *text = QString::fromUtf8(bytes);
    return in.status() == QDataStream::Ok;
}

void writeString(QDataStream &out, const QString &text)
{
    const QByteArray bytes = text.toUtf8().left(65535);
    out << quint16(bytes.size());
    out.writeRawData(bytes.constData(), int(bytes.size()));
}

bool readPayload(QDataStream &in, Type type, Tag *tag, int depth)
{
    if (depth > MaxDepth) return false;
    tag->type = type;
    switch (type) {
    case Byte: { qint8 v; in >> v; tag->value = v; break; }
    case Short: { qint16 v; in >> v; tag->value = v; break; }
    case Int: { qint32 v; in >> v; tag->value = v; break; }
    case Long: { qint64 v; in >> v; tag->value = v; break; }
    case Float: { float v; in.setFloatingPointPrecision(QDataStream::SinglePrecision); in >> v; tag->value = v; break; }
    case Double: { double v; in.setFloatingPointPrecision(QDataStream::DoublePrecision); in >> v; tag->value = v; break; }
    case ByteArray: {
        qint32 n; in >> n;
        if (n < 0 || n > MaxElements * 16) return false;
        tag->bytes.resize(n);
        if (in.readRawData(tag->bytes.data(), n) != n) return false;
        break;
    }
    case String: { QString s; if (!readString(in, &s)) return false; tag->value = s; break; }
    case List: {
        quint8 itemType; qint32 n; in >> itemType >> n;
        if (n < 0 || n > MaxElements || itemType > LongArray) return false;
        tag->listType = Type(itemType);
        for (qint32 i = 0; i < n; ++i) {
            Tag item;
            if (!readPayload(in, tag->listType, &item, depth + 1)) return false;
            tag->items.append(item);
        }
        break;
    }
    case Compound:
        for (;;) {
            quint8 childType; in >> childType;
            if (in.status() != QDataStream::Ok || childType > LongArray) return false;
            if (childType == End) break;
            QString name;
            Tag child;
            if (!readString(in, &name) || !readPayload(in, Type(childType), &child, depth + 1)) return false;
            tag->children.append({name, child});
        }
        break;
    case IntArray:
    case LongArray: {
        qint32 n; in >> n;
        if (n < 0 || n > MaxElements) return false;
        for (qint32 i = 0; i < n; ++i) {
            if (type == IntArray) { qint32 v; in >> v; tag->numbers.append(v); }
            else { qint64 v; in >> v; tag->numbers.append(v); }
        }
        break;
    }
    case End:
        return false;
    }
    return in.status() == QDataStream::Ok;
}

void writePayload(QDataStream &out, const Tag &tag)
{
    switch (tag.type) {
    case Byte: out << qint8(tag.value.toInt()); break;
    case Short: out << qint16(tag.value.toInt()); break;
    case Int: out << qint32(tag.value.toInt()); break;
    case Long: out << qint64(tag.value.toLongLong()); break;
    case Float: out.setFloatingPointPrecision(QDataStream::SinglePrecision); out << tag.value.toFloat(); break;
    case Double: out.setFloatingPointPrecision(QDataStream::DoublePrecision); out << tag.value.toDouble(); break;
    case ByteArray: out << qint32(tag.bytes.size()); out.writeRawData(tag.bytes.constData(), int(tag.bytes.size())); break;
    case String: writeString(out, tag.value.toString()); break;
    case List:
        out << quint8(tag.items.isEmpty() && tag.listType == End ? End : tag.listType) << qint32(tag.items.size());
        for (const Tag &item : tag.items) writePayload(out, item);
        break;
    case Compound:
        for (const auto &[name, child] : tag.children) {
            out << quint8(child.type);
            writeString(out, name);
            writePayload(out, child);
        }
        out << quint8(End);
        break;
    case IntArray:
    case LongArray:
        out << qint32(tag.numbers.size());
        for (qint64 v : tag.numbers) {
            if (tag.type == IntArray) out << qint32(v);
            else out << v;
        }
        break;
    case End: break;
    }
}
}

const Tag *Tag::child(const QString &name) const
{
    for (const auto &entry : children)
        if (entry.first == name) return &entry.second;
    return nullptr;
}

Tag *Tag::child(const QString &name)
{
    for (auto &entry : children)
        if (entry.first == name) return &entry.second;
    return nullptr;
}

QString Tag::string(const QString &name) const
{
    const Tag *tag = child(name);
    return tag && tag->type == String ? tag->value.toString() : QString();
}

void Tag::setString(const QString &name, const QString &text)
{
    if (Tag *tag = child(name)) *tag = makeString(text);
    else children.append({name, makeString(text)});
}

Tag Tag::makeString(const QString &text)
{
    Tag tag;
    tag.type = String;
    tag.value = text;
    return tag;
}

Tag Tag::makeByte(qint8 value)
{
    Tag tag;
    tag.type = Byte;
    tag.value = value;
    return tag;
}

bool read(const QByteArray &data, Tag *root, QString *rootName)
{
    QDataStream in(data);
    in.setByteOrder(QDataStream::BigEndian);
    quint8 type = 0;
    in >> type;
    QString name;
    Tag tag;
    if (type != Compound || !readString(in, &name) || !readPayload(in, Compound, &tag, 0)) return false;
    *root = tag;
    if (rootName) *rootName = name;
    return true;
}

QByteArray write(const Tag &root, const QString &rootName)
{
    QByteArray data;
    QDataStream out(&data, QIODevice::WriteOnly);
    out.setByteOrder(QDataStream::BigEndian);
    out << quint8(Compound);
    writeString(out, rootName);
    writePayload(out, root);
    return data;
}
}
