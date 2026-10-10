#pragma once
#include <QObject>
#include <QHash>
#include <QSet>
#include <QTimer>
#include <QUdpSocket>
#include <QVariantList>

// Opt-in signed LAN presence. Only already trusted keys are displayed.
class LanDiscovery : public QObject {
    Q_OBJECT
public:
    explicit LanDiscovery(QObject *parent = nullptr);
    ~LanDiscovery() override;
    bool start(const QByteArray &seed, const QSet<QByteArray> &friends);
    void stop();
    void setFriends(const QSet<QByteArray> &friends);
    bool active() const { return m_socket.state() == QAbstractSocket::BoundState; }
    QVariantList peers() const;
    // Separately callable protocol boundary for deterministic adversarial tests.
    bool receive(const QByteArray &packet, const QHostAddress &sender, qint64 now);
signals:
    void changed();
private:
    void announce();
    struct Peer { QString address; qint64 issued; qint64 seen; };
    QUdpSocket m_socket;
    QTimer m_timer;
    QByteArray m_seed;
    QSet<QByteArray> m_friends;
    QHash<QByteArray, Peer> m_peers;
    QHash<QByteArray, qint64> m_lastIssued;
};
