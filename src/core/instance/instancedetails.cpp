#include "instancedetails.h"
#include "../prism/paths.h"
#include <QtConcurrent>
#include <QFutureWatcher>
#include <QFileInfo>

InstanceDetails::InstanceDetails(InstanceModel *model, QObject *parent)
    : QObject(parent), m_model(model)
{
    m_refreshTimer.setInterval(350);
    m_refreshTimer.setSingleShot(true);
    connect(&m_watcher, &QFileSystemWatcher::directoryChanged, this, [this] { m_refreshTimer.start(); });
    connect(&m_watcher, &QFileSystemWatcher::fileChanged, this, [this] { m_refreshTimer.start(); });
    connect(&m_refreshTimer, &QTimer::timeout, this, &InstanceDetails::refresh);
}
void InstanceDetails::load(const QString &id)
{
    const QString path = m_model->instancePath(id);
    const quint64 generation = ++m_generation;
    m_id = id;
    m_gamePath = path.isEmpty() ? QString() : Prism::gameDir(path);
    m_contents = {};
    m_contents.info = m_model->getById(id);
    m_loading = !path.isEmpty();
    if (!m_watcher.directories().isEmpty()) m_watcher.removePaths(m_watcher.directories());
    if (!m_watcher.files().isEmpty()) m_watcher.removePaths(m_watcher.files());
    QStringList watched{path + "/instance.cfg", m_gamePath, m_gamePath + "/mods", m_gamePath + "/screenshots", m_gamePath + "/resourcepacks", m_gamePath + "/shaderpacks", m_gamePath + "/saves"};
    for (const auto &watchedPath : watched) if (!path.isEmpty() && QFileInfo::exists(watchedPath)) m_watcher.addPath(watchedPath);
    emit changed();
    if (path.isEmpty()) return;
    auto *watcher = new QFutureWatcher<InstanceContents>(this);
    connect(watcher, &QFutureWatcher<InstanceContents>::finished, this, [this, watcher, generation] {
        if (generation == m_generation) {
            m_contents = watcher->result();
            m_loading = false;
            emit changed();
        }
        watcher->deleteLater();
    });
    watcher->setFuture(QtConcurrent::run([path, dataDir = m_model->dataDir(), info = m_contents.info] { return InstanceContent::scan(path, dataDir, info); }));
}
void InstanceDetails::refresh() { if (!m_id.isEmpty()) load(m_id); }
