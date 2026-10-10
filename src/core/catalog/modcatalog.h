#pragma once
#include <QObject>
#include <QNetworkAccessManager>
#include <QVariantList>
#include <QUrl>

class ModCatalog : public QObject {
    Q_OBJECT
    Q_PROPERTY(QString provider READ provider WRITE setProvider NOTIFY changed)
    Q_PROPERTY(bool curseForgeReady READ curseForgeReady NOTIFY credentialsChanged)
    Q_PROPERTY(QVariantMap project READ project NOTIFY changed)
    Q_PROPERTY(QVariantList results READ results NOTIFY changed)
    Q_PROPERTY(QVariantList versions READ versions NOTIFY changed)
    Q_PROPERTY(bool loading READ loading NOTIFY changed)
    Q_PROPERTY(bool versionsLoading READ versionsLoading NOTIFY changed)
    Q_PROPERTY(QString error READ error NOTIFY changed)
    Q_PROPERTY(QVariantList categoryTags READ categoryTags NOTIFY categoriesChanged)
public:
    explicit ModCatalog(QObject *parent = nullptr, const QUrl &apiRoot = QUrl("https://api.modrinth.com/v2"),
                        const QUrl &curseApi = QUrl("https://api.curseforge.com/v1"));
    QString provider() const { return m_provider; }
    void setProvider(const QString &provider);
    bool curseForgeReady() const { return !m_curseKey.isEmpty(); }
    QByteArray curseForgeKey() const { return m_curseKey; }
    void loadCredentials();
    Q_INVOKABLE void setCurseForgeKey(const QString &key, bool remember = false);
    QVariantMap project() const { return m_project; }
    Q_INVOKABLE void loadProject(const QString &id);
    QVariantList results() const { return m_results; }
    QVariantList versions() const { return m_versions; }
    bool loading() const { return m_loading; }
    bool versionsLoading() const { return m_versionsLoading; }
    QString error() const { return m_error; }
    QVariantList categoryTags() const { return m_categoryTags; }
    Q_INVOKABLE void search(const QString &query, const QString &version, const QString &loader, const QString &type = "mod",
                            const QStringList &categories = {});
    // Fetches Modrinth's category tags once; categoriesFor() then filters them by project type.
    Q_INVOKABLE void loadCategories();
    Q_INVOKABLE QStringList categoriesFor(const QString &type) const;
    Q_INVOKABLE void loadVersions(const QString &projectId, const QString &version, const QString &loader);
signals:
    void credentialsChanged();
    void changed();
    void categoriesChanged();
private:
    void searchCurseForge(const QString &query, const QString &version, const QString &loader, const QString &type, quint64 generation);
    void curseForgeVersions(const QString &id, const QString &version, const QString &loader, quint64 generation);
    void curseForgeProject(const QString &id, quint64 generation);
    QNetworkRequest curseRequest(const QUrl &url) const;
    QNetworkRequest request(const QUrl &url) const;
    QUrl m_apiRoot, m_curseApi;
    QString m_provider = "modrinth";
    QByteArray m_curseKey;
    quint64 m_credentialsGeneration = 0;
    QNetworkAccessManager m_network;
    QVariantMap m_project;
    quint64 m_projectGeneration = 0;
    QVariantList m_results, m_versions;
    bool m_loading = false, m_versionsLoading = false;
    QString m_error;
    QVariantList m_categoryTags;
    bool m_categoriesRequested = false;
    quint64 m_searchGeneration = 0, m_versionGeneration = 0;
};
