#include "packimporter.h"
#include <QtConcurrent>
#include <QFutureWatcher>
#include <QDir>
#include <QUuid>
#include <QRegularExpression>

void PackImporter::cancel()
{
    ++m_generation; if (m_reply) m_reply->abort(); m_reply.clear(); m_staging.reset(); m_archive.reset();
    m_state = "idle"; m_error.clear(); m_progress = 0; emit changed();
}
void PackImporter::fail(const QString &error) { m_state = "error"; m_error = error; m_staging.reset(); emit changed(); }
void PackImporter::importFile(const QUrl &source)
{
    const auto archive = m_archive;
    cancel();
    m_archive = archive;
    if (!source.isLocalFile()) { fail("Choose a local pack archive."); return; }
    if (!QDir().mkpath(m_model->instanceDir())) { fail("Cannot create the instances folder."); return; }
    m_staging = std::make_shared<QTemporaryDir>(m_model->instanceDir() + "/.prismarine-pack-XXXXXX");
    if (!m_staging->isValid()) { fail("Cannot prepare this import."); return; }
    m_source = source;
    m_state = "extracting"; emit changed(); const auto generation = m_generation; const auto staging = m_staging;
    auto *watcher = new QFutureWatcher<PackPlan>(this);
    connect(watcher, &QFutureWatcher<PackPlan>::finished, this, [this, watcher, generation] {
        const auto plan = watcher->result(); watcher->deleteLater(); if (generation != m_generation) return;
        if (!plan.error.isEmpty()) { fail(plan.error); return; }
        if (plan.foreign) {
            m_staging.reset();
            if (!m_model->importPack(m_source)) { fail("Prism could not start the " + plan.name + " import."); return; }
            m_state = "handedoff"; m_progress = 1; emit changed(); emit handedOff(plan.name); return;
        }
        m_plan = plan; m_index = 0; m_state = "downloading"; emit changed(); downloadNext();
    });
    watcher->setFuture(QtConcurrent::run([source, staging, archive] { return extractPack(source.toLocalFile(), staging->path()); }));
}
void PackImporter::finish()
{
    QString error;
    if (m_plan.modrinth && !applyPackOverrides(m_staging->path(), &error)) { fail(error); return; }
    QString slug = m_plan.name; slug.replace(QRegularExpression("[^A-Za-z0-9_-]+"), "-");
    if (slug.isEmpty()) slug = "Imported-pack";
    const QString id = slug.left(64) + "-" + QUuid::createUuid().toString(QUuid::Id128).left(8);
    if (!QDir().rename(m_plan.instanceRoot, m_model->instanceDir() + "/" + id)) { fail("Cannot finish importing this pack."); return; }
    m_staging.reset(); m_state = "complete"; m_progress = 1; m_model->reload(); emit changed(); emit imported(id);
}
