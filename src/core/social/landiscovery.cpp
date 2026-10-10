#include "landiscovery.h"
#include "crypto.h"
#include "socialprotocol.h"
#include <QDateTime>
#include <QNetworkDatagram>
#include <QNetworkInterface>
#include <QJsonDocument>

namespace {
const QHostAddress Group("239.255.73.77");
constexpr quint16 Port = 45837;
constexpr qint64 Lifetime = 15000;
}
LanDiscovery::LanDiscovery(QObject *parent) : QObject(parent)
{
    m_timer.setInterval(5000);
    connect(&m_timer, &QTimer::timeout, this, &LanDiscovery::announce);
    connect(&m_socket, &QUdpSocket::readyRead, this, [this] {
        int remaining = 64;
        while (m_socket.hasPendingDatagrams() && remaining-- > 0) {
            const auto datagram = m_socket.receiveDatagram(2049);
            receive(datagram.data(), datagram.senderAddress(), QDateTime::currentMSecsSinceEpoch());
        }
        // Yield under floods, then drain again without monopolising the GUI thread.
        if (m_socket.hasPendingDatagrams()) QTimer::singleShot(0, &m_socket, [this] { emit m_socket.readyRead(); });
    });
}
LanDiscovery::~LanDiscovery() { stop(); }
bool LanDiscovery::start(const QByteArray &seed, const QSet<QByteArray> &friends)
{
    stop();
    if (seed.size() != 32 || !m_socket.bind(QHostAddress::AnyIPv4, Port, QUdpSocket::ShareAddress | QUdpSocket::ReuseAddressHint)) return false;
    bool joined = false;
    for (const auto &iface : QNetworkInterface::allInterfaces()) {
        const auto flags = iface.flags();
        if (!(flags & QNetworkInterface::IsUp) || !(flags & QNetworkInterface::CanMulticast) || (flags & QNetworkInterface::IsLoopBack)) continue;
        if (m_socket.joinMulticastGroup(Group, iface)) joined = true;
    }
    if (!joined) { m_socket.close(); return false; }
    m_socket.setSocketOption(QAbstractSocket::MulticastTtlOption, 1);
    m_seed = seed; m_friends = friends;
    m_timer.start(); announce(); emit changed();
    return true;
}
void LanDiscovery::stop()
{
    m_timer.stop(); m_socket.close(); Crypto::clearSecret(m_seed);
    m_peers.clear(); m_lastIssued.clear(); emit changed();
}
void LanDiscovery::setFriends(const QSet<QByteArray> &friends)
{
    m_friends = friends;
    for (auto it = m_peers.begin(); it != m_peers.end();) {
        if (!friends.contains(it.key())) it = m_peers.erase(it); else ++it;
    }
    for (auto it = m_lastIssued.begin(); it != m_lastIssued.end();) {
        if (!friends.contains(it.key())) it = m_lastIssued.erase(it); else ++it;
    }
    emit changed();
}
void LanDiscovery::announce()
{
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    const auto packet = SocialProtocol::seal({{"type", "presence"}, {"issued", now}, {"expires", now + Lifetime}}, m_seed);
    for (const auto &iface : QNetworkInterface::allInterfaces()) {
        const auto flags = iface.flags();
        if ((flags & QNetworkInterface::IsUp) && (flags & QNetworkInterface::CanMulticast) && !(flags & QNetworkInterface::IsLoopBack)) {
            m_socket.setMulticastInterface(iface);
            m_socket.writeDatagram(packet, Group, Port);
        }
    }
    for (auto it = m_peers.begin(); it != m_peers.end();) {
        if (now - it->seen >= Lifetime) it = m_peers.erase(it); else ++it;
    }
    emit changed();
}
bool LanDiscovery::receive(const QByteArray &packet, const QHostAddress &sender, qint64 now)
{
    if (packet.size() > 2048 || sender.isNull() || sender.isMulticast() || sender == QHostAddress::AnyIPv4) return false;
    // Drop unknown senders before doing public-key work. This is only a cheap filter;
    // open() still verifies the complete signature against the claimed key below.
    const auto claimed = QJsonDocument::fromJson(packet).object().value("publicKey").toString();
    if (!m_friends.contains(Crypto::fromBase64Url(claimed))) return false;
    const auto verified = SocialProtocol::open(packet, "presence");
    if (!verified || !m_friends.contains(verified.publicKey)) return false;
    const qint64 issued = verified.payload.value("issued").toInteger(), expires = verified.payload.value("expires").toInteger();
    if (issued <= 0 || issued > now + 2000 || expires <= now || expires - issued != Lifetime
        || issued <= m_lastIssued.value(verified.publicKey)) return false;
    m_lastIssued.insert(verified.publicKey, issued);
    m_peers.insert(verified.publicKey, {sender.toString(), issued, now});
    emit changed(); return true;
}
QVariantList LanDiscovery::peers() const
{
    QVariantList list;
    const qint64 now = QDateTime::currentMSecsSinceEpoch();
    for (auto it = m_peers.cbegin(); it != m_peers.cend(); ++it)
        if (now - it->seen < Lifetime) list.append(QVariantMap{{"key", Crypto::base64Url(it.key())}, {"address", it->address}});
    return list;
}
