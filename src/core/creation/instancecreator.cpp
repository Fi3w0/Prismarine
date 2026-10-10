#include "instancecreator.h"
#include "../prism/configwriter.h"
#include <QNetworkReply>
#include <QJsonDocument>
#include <QJsonObject>
#include <QJsonArray>
#include <QTemporaryDir>
#include <QSaveFile>
#include <QDir>
#include <QRegularExpression>
#include <QUuid>
#include <algorithm>

static QString loaderUid(const QString &name)
{
    return QMap<QString, QString>{{"Fabric", "net.fabricmc.fabric-loader"}, {"Quilt", "org.quiltmc.quilt-loader"},
        {"Forge", "net.minecraftforge"}, {"NeoForge", "net.neoforged"}}.value(name);
}
InstanceCreator::InstanceCreator(InstanceModel *model, QObject *parent, const QUrl &metadata)
    : QObject(parent), m_model(model), m_metadata(metadata) {}
void InstanceCreator::fetch(const QString &uid, std::function<void(const QJsonArray &)> done)
{
    const auto generation = ++m_generation;
    m_loading = true; m_error.clear(); emit changed();
    QNetworkRequest req(QUrl(m_metadata.toString() + "/" + uid + "/index.json"));
    req.setTransferTimeout(15000); req.setRawHeader("User-Agent", "Prismarine/0.4.0");
    auto *reply = m_network.get(req);
    connect(reply, &QNetworkReply::finished, this, [this, reply, generation, done] {
        if (generation == m_generation) {
            m_loading = false;
            const auto doc = QJsonDocument::fromJson(reply->readAll());
            if (reply->error() != QNetworkReply::NoError || !doc.object().value("versions").isArray())
                m_error = "Could not load the version list. Check your connection and retry.";
            else done(doc.object().value("versions").toArray());
            emit changed();
        }
        reply->deleteLater();
    });
}
void InstanceCreator::loadVersions(bool snapshots)
{
    if (m_copying) return;
    m_versions.clear(); m_loaderVersions.clear(); m_loader.clear(); m_minecraft.clear();
    fetch("net.minecraft", [this, snapshots](const QJsonArray &versions) {
        for (const auto &v : versions) {
            const auto o = v.toObject();
            if (snapshots || o.value("type") == "release") m_versions.append(o.toVariantMap());
        }
    });
}
void InstanceCreator::loadLoader(const QString &loader, const QString &minecraft)
{
    if (m_copying) return;
    m_loaderVersions.clear(); m_loader = loader; m_minecraft = minecraft;
    if (loader == "Vanilla") { ++m_generation; m_loading = false; m_error.clear(); emit changed(); return; }
    const QString uid = loaderUid(loader);
    if (uid.isEmpty()) { m_error = "Unknown loader."; emit changed(); return; }
    fetch(uid, [this, minecraft](const QJsonArray &versions) {
        for (const auto &v : versions) {
            const auto o = v.toObject(); bool compatible = true;
            for (const auto &r : o.value("requires").toArray()) {
                const auto req = r.toObject();
                if (req.value("uid") == "net.minecraft" && req.contains("equals") && req.value("equals") != minecraft)
                    compatible = false;
            }
            if (compatible) m_loaderVersions.append(o.toVariantMap());
        }
        std::stable_sort(m_loaderVersions.begin(), m_loaderVersions.end(), [](const QVariant &a, const QVariant &b) {
            const auto first = a.toMap(), second = b.toMap();
            if (first.value("recommended").toBool() != second.value("recommended").toBool()) return first.value("recommended").toBool();
            return first.value("type") == "release" && second.value("type") != "release";
        });
    });
}
QString InstanceCreator::create(const QString &name, const QString &minecraft, const QString &loader, const QString &loaderVersion)
{
    m_error.clear();
    const auto fail = [this](const QString &e) { m_error = e; emit changed(); return QString(); };
    if (name.trimmed().isEmpty() || name.contains(QRegularExpression("[\\r\\n\\x{0000}]"))) return fail("Give your instance a name.");
    const auto contains = [](const QVariantList &list, const QString &version) {
        for (const auto &v : list) if (v.toMap().value("version") == version) return true;
        return false;
    };
    if (m_loading || !contains(m_versions, minecraft)) return fail("Select a Minecraft version from the list.");
    if (loader != "Vanilla" && (loader != m_loader || minecraft != m_minecraft || !contains(m_loaderVersions, loaderVersion)))
        return fail("Select a compatible loader version.");
    const QString root = m_model->instanceDir();
    if (!QDir().mkpath(root)) return fail("Cannot create the instance directory.");
    QTemporaryDir staging(root + "/.prismarine-create-XXXXXX");
    if (!staging.isValid()) return fail("Cannot prepare the new instance.");
    QJsonArray components{QJsonObject{{"uid", "net.minecraft"}, {"version", minecraft}, {"important", true}}};
    if (loader == "Fabric") components.append(QJsonObject{{"uid", "net.fabricmc.intermediary"}, {"version", minecraft}, {"dependencyOnly", true}});
    if (loader == "Quilt") components.append(QJsonObject{{"uid", "net.fabricmc.intermediary"}, {"version", minecraft}, {"dependencyOnly", true}});
    if (loader != "Vanilla") components.append(QJsonObject{{"uid", loaderUid(loader)}, {"version", loaderVersion}});
    const QByteArray pack = QJsonDocument(QJsonObject{{"formatVersion", 1}, {"components", components}}).toJson();
    QSaveFile output(staging.path() + "/mmc-pack.json");
    if (!output.open(QIODevice::WriteOnly) || output.write(pack) != pack.size() || !output.commit()) return fail("Cannot save the version manifest.");
    QString error;
    if (!Prism::writeConfig(staging.path() + "/instance.cfg", {{"InstanceType", "OneSix"}, {"name", name.trimmed()}, {"iconKey", "default"}}, &error, false)) return fail(error);
    QDir().mkpath(staging.path() + "/.minecraft");
    QString slug = name.trimmed(); slug.replace(QRegularExpression("[^A-Za-z0-9_-]+"), "-");
    if (slug.isEmpty()) slug = "Minecraft";
    const QString id = slug.left(64) + "-" + QUuid::createUuid().toString(QUuid::Id128).left(8);
    if (!QDir().rename(staging.path(), root + "/" + id)) return fail("Cannot finish creating the instance.");
    m_model->reload(); emit created(id); emit changed(); return id;
}
