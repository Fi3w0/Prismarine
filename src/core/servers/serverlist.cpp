#include "serverlist.h"
#include "../library/instancemodel.h"
#include "../prism/paths.h"
#include <QDnsLookup>
#include <QElapsedTimer>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QRegularExpression>
#include <QSaveFile>
#include <QTcpSocket>
#include <QTimer>

namespace {
constexpr int PingTimeoutMs = 6000;
constexpr int MaxStatusBytes = 1024 * 1024;
constexpr int ProtocolVersion = 767;

void putVarInt(QByteArray &out, quint32 value)
{
    do {
        quint8 byte = value & 0x7F;
        value >>= 7;
        if (value) byte |= 0x80;
        out.append(char(byte));
    } while (value);
}

// Returns false while more bytes are needed; *ok turns false for a malformed number.
bool takeVarInt(const QByteArray &data, int *offset, qint32 *value, bool *ok)
{
    quint32 result = 0;
    for (int shift = 0, i = *offset; shift < 35; shift += 7, ++i) {
        if (i >= data.size()) return false;
        const quint8 byte = quint8(data.at(i));
        result |= quint32(byte & 0x7F) << shift;
        if (!(byte & 0x80)) {
            *offset = i + 1;
            *value = qint32(result);
            return true;
        }
    }
    *ok = false;
    return false;
}

QByteArray packet(const QByteArray &body)
{
    QByteArray framed;
    putVarInt(framed, quint32(body.size()));
    return framed + body;
}
}

ServerList::ServerList(InstanceModel *instances, QObject *parent) : QObject(parent), m_instances(instances) {}

bool ServerList::validAddress(const QString &address)
{
    static const QRegularExpression allowed(QStringLiteral(R"(^[A-Za-z0-9._\-]+(:\d{1,5})?$|^\[[0-9A-Fa-f:.]+\](:\d{1,5})?$)"));
    return address.size() <= 255 && allowed.match(address).hasMatch();
}

QPair<QString, quint16> ServerList::splitAddress(const QString &address, bool *explicitPort)
{
    QString host = address;
    quint16 port = 25565;
    bool hasPort = false;
    if (address.startsWith('[')) {
        const int end = address.indexOf(']');
        host = address.mid(1, end - 1);
        if (address.mid(end + 1).startsWith(':')) { port = quint16(address.mid(end + 2).toUInt()); hasPort = true; }
    } else if (address.count(':') == 1) {
        host = address.section(':', 0, 0);
        port = quint16(address.section(':', 1).toUInt());
        hasPort = true;
    }
    if (explicitPort) *explicitPort = hasPort;
    return {host, port ? port : quint16(25565)};
}

QString ServerList::plainMotd(const QJsonValue &description)
{
    QString text;
    if (description.isString()) text = description.toString();
    else if (description.isObject()) {
        const QJsonObject component = description.toObject();
        text = component.value("text").toString();
        for (const auto &extra : component.value("extra").toArray()) text += plainMotd(extra);
    } else if (description.isArray()) {
        for (const auto &part : description.toArray()) text += plainMotd(part);
    }
    // Legacy formatting codes such as "§a" carry no meaning outside the game.
    static const QRegularExpression codes(QStringLiteral("§."));
    return text.remove(codes);
}

void ServerList::load(const QString &instanceId)
{
    ++m_generation;
    const QString path = m_instances ? m_instances->instancePath(instanceId) : QString();
    m_instanceId = instanceId;
    m_file = path.isEmpty() ? QString() : Prism::gameDir(path) + "/servers.dat";
    m_root = {};
    m_root.type = Nbt::Compound;
    m_rootName.clear();
    m_servers.clear();
    m_status.clear();
    QFile file(m_file);
    if (!m_file.isEmpty() && file.exists()) {
        if (!file.open(QIODevice::ReadOnly) || file.size() > 16 * 1024 * 1024 || !Nbt::read(file.readAll(), &m_root, &m_rootName)) {
            m_root = {};
            m_root.type = Nbt::Compound;
            emit errorOccurred("This instance's server list could not be read.");
        }
    }
    if (const Nbt::Tag *list = m_root.child("servers"); list && list->type == Nbt::List) {
        for (int i = 0; i < list->items.size(); ++i) {
            const Nbt::Tag &server = list->items.at(i);
            if (server.type != Nbt::Compound) continue;
            const QString icon = server.string("icon");
            const Nbt::Tag *hidden = server.child("hidden");
            m_servers.append(QVariantMap{{"index", i}, {"name", server.string("name")}, {"address", server.string("ip").trimmed()},
                                         {"icon", icon.isEmpty() ? QString() : "data:image/png;base64," + icon},
                                         {"hidden", hidden && hidden->value.toInt() != 0}});
        }
    }
    emit changed();
    emit statusChanged();
    refresh();
}

void ServerList::refresh()
{
    ++m_generation;
    m_status.clear();
    for (const QVariant &server : m_servers) ping(server.toMap().value("address").toString());
    emit statusChanged();
}

void ServerList::setStatus(const QString &address, const QVariantMap &status)
{
    m_status.insert(address, status);
    emit statusChanged();
}

void ServerList::ping(const QString &address)
{
    if (!validAddress(address)) { setStatus(address, {{"state", "offline"}, {"reason", "Invalid address"}}); return; }
    setStatus(address, {{"state", "pinging"}});
    const quint64 generation = m_generation;
    bool explicitPort = false;
    const auto split = splitAddress(address, &explicitPort);
    const QString host = split.first;
    const quint16 port = split.second;
    if (explicitPort || host.contains(':') || QRegularExpression(QStringLiteral(R"(^\d+\.\d+\.\d+\.\d+$)")).match(host).hasMatch()) {
        connectAndQuery(address, host, port, generation);
        return;
    }
    // Like the game, honour _minecraft._tcp SRV records for addresses without a port.
    auto *lookup = new QDnsLookup(QDnsLookup::SRV, "_minecraft._tcp." + host, this);
    connect(lookup, &QDnsLookup::finished, this, [this, lookup, address, host, port, generation] {
        lookup->deleteLater();
        const auto records = lookup->serviceRecords();
        if (lookup->error() == QDnsLookup::NoError && !records.isEmpty())
            connectAndQuery(address, records.first().target(), records.first().port(), generation);
        else
            connectAndQuery(address, host, port, generation);
    });
    lookup->lookup();
}

void ServerList::connectAndQuery(const QString &address, const QString &host, quint16 port, quint64 generation)
{
    if (generation != m_generation) return;
    auto *socket = new QTcpSocket(this);
    auto *timeout = new QTimer(socket);
    auto clock = std::make_shared<QElapsedTimer>();
    auto buffer = std::make_shared<QByteArray>();
    const auto finish = [this, socket, address, generation](const QVariantMap &status) {
        if (socket->property("done").toBool()) return;
        socket->setProperty("done", true);
        if (generation == m_generation) setStatus(address, status);
        socket->abort();
        socket->deleteLater();
    };
    timeout->setSingleShot(true);
    connect(timeout, &QTimer::timeout, this, [finish] { finish({{"state", "offline"}, {"reason", "No response"}}); });
    connect(socket, &QTcpSocket::errorOccurred, this, [finish] { finish({{"state", "offline"}, {"reason", "Can't connect"}}); });
    connect(socket, &QTcpSocket::connected, this, [socket, host, port, clock] {
        QByteArray handshake;
        putVarInt(handshake, 0x00);
        putVarInt(handshake, ProtocolVersion);
        const QByteArray hostBytes = host.toUtf8();
        putVarInt(handshake, quint32(hostBytes.size()));
        handshake += hostBytes;
        handshake.append(char(port >> 8)).append(char(port & 0xFF));
        putVarInt(handshake, 1);
        socket->write(packet(handshake) + packet(QByteArray(1, '\0')));
        clock->start();
    });
    connect(socket, &QTcpSocket::readyRead, this, [socket, buffer, clock, finish] {
        buffer->append(socket->readAll());
        if (buffer->size() > MaxStatusBytes) { finish({{"state", "offline"}, {"reason", "Response too large"}}); return; }
        int offset = 0;
        qint32 length = 0, id = 0, jsonLength = 0;
        bool ok = true;
        if (!takeVarInt(*buffer, &offset, &length, &ok)) { if (!ok) finish({{"state", "offline"}, {"reason", "Unreadable response"}}); return; }
        if (length < 0 || length > MaxStatusBytes) { finish({{"state", "offline"}, {"reason", "Unreadable response"}}); return; }
        if (buffer->size() - offset < length) return;
        if (!takeVarInt(*buffer, &offset, &id, &ok) || id != 0 || !takeVarInt(*buffer, &offset, &jsonLength, &ok)
            || jsonLength < 0 || offset + jsonLength > buffer->size()) {
            finish({{"state", "offline"}, {"reason", "Unreadable response"}});
            return;
        }
        const QJsonObject status = QJsonDocument::fromJson(buffer->mid(offset, jsonLength)).object();
        const QJsonObject players = status.value("players").toObject();
        const QString favicon = status.value("favicon").toString();
        finish({{"state", "online"}, {"latency", qint64(clock->elapsed())},
                {"players", players.value("online").toInt()}, {"max", players.value("max").toInt()},
                {"motd", plainMotd(status.value("description")).trimmed()},
                {"version", status.value("version").toObject().value("name").toString()},
                {"favicon", favicon.startsWith("data:image/png;base64,") ? favicon : QString()}});
    });
    timeout->start(PingTimeoutMs);
    socket->connectToHost(host, port);
}

bool ServerList::save()
{
    // Minecraft keeps the previous list as servers.dat_old; do the same before replacing it.
    if (QFile::exists(m_file)) {
        QFile::remove(m_file + "_old");
        QFile::copy(m_file, m_file + "_old");
    }
    QSaveFile output(m_file);
    const QByteArray bytes = Nbt::write(m_root, m_rootName);
    if (!output.open(QIODevice::WriteOnly) || output.write(bytes) != bytes.size() || !output.commit()) {
        emit errorOccurred("Could not save the server list.");
        return false;
    }
    return true;
}

bool ServerList::add(const QString &name, const QString &address)
{
    const QString trimmed = address.trimmed();
    if (m_file.isEmpty() || !validAddress(trimmed)) {
        emit errorOccurred("Enter a server address like play.example.com or 192.168.1.4:25565.");
        return false;
    }
    Nbt::Tag *list = m_root.child("servers");
    if (!list) {
        Nbt::Tag empty;
        empty.type = Nbt::List;
        empty.listType = Nbt::Compound;
        m_root.children.append({"servers", empty});
        list = m_root.child("servers");
    }
    if (list->type != Nbt::List) return false;
    list->listType = Nbt::Compound;
    Nbt::Tag server;
    server.type = Nbt::Compound;
    server.setString("name", name.trimmed().isEmpty() ? QStringLiteral("Minecraft Server") : name.trimmed().left(64));
    server.setString("ip", trimmed);
    list->items.append(server);
    if (!save()) return false;
    load(m_instanceId);
    return true;
}

bool ServerList::remove(int index)
{
    Nbt::Tag *list = m_root.child("servers");
    if (!list || list->type != Nbt::List || index < 0 || index >= list->items.size()) return false;
    list->items.removeAt(index);
    if (!save()) return false;
    load(m_instanceId);
    return true;
}

bool ServerList::join(int index)
{
    for (const QVariant &value : m_servers) {
        const QVariantMap server = value.toMap();
        if (server.value("index").toInt() == index) return m_instances->launchServer(m_instanceId, server.value("address").toString());
    }
    return false;
}

void ServerList::pingAddresses(const QStringList &addresses)
{
    ++m_generation;
    for (const auto &address : addresses) ping(address);
}
