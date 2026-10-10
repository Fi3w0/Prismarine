#include "javamanager.h"
#include "../prism/configreader.h"
#include <QCryptographicHash>
#include <QDir>
#include <QDirIterator>
#include <QFile>
#include <QFutureWatcher>
#include <QJsonArray>
#include <QJsonDocument>
#include <QJsonObject>
#include <QProcess>
#include <QRegularExpression>
#include <QStandardPaths>
#include <QSysInfo>
#include <QSet>
#include <QUrlQuery>
#include <QUuid>
#include <QtConcurrent>

QVariantMap JavaRuntime::probe(const QString &path, const QStringList &arguments)
{
    QProcess process;
    process.setProcessChannelMode(QProcess::MergedChannels);
    process.start(path, arguments + QStringList{"-XshowSettings:properties", "-version"});
    if (!process.waitForStarted(3000)) return {{"error", "Java could not start: " + process.errorString()}};
    if (!process.waitForFinished(8000)) { process.kill(); process.waitForFinished(1000); return {{"error", "Java did not respond within eight seconds."}}; }
    const QString output = QString::fromUtf8(process.readAll().left(65536));
    if (process.exitStatus() != QProcess::NormalExit || process.exitCode() != 0) return {{"error", output.isEmpty() ? "Java exited with an error." : output}};
    const auto property = [&](const QString &name) {
        return QRegularExpression("(?m)^\\s*" + QRegularExpression::escape(name) + "\\s*=\\s*([^\\r\\n]+)").match(output).captured(1).trimmed();
    };
    const auto version = property("java.version");
    if (version.isEmpty()) return {{"error", "The executable did not report a Java version."}};
    return {{"path", QFileInfo(path).canonicalFilePath()}, {"version", version}, {"vendor", property("java.vendor")},
            {"architecture", property("os.arch")}, {"label", version + " · " + property("java.vendor") + " · " + property("os.arch")}};
}
JavaManager::JavaManager(InstanceModel *model, QObject *parent, const QUrl &api) : QObject(parent), m_model(model), m_api(api) {}
QString JavaManager::installRoot() const { return m_model->dataDir() + "/java/prismarine"; }
void JavaManager::finish(const QString &message) { m_busy = false; m_message = message; emit changed(); }
void JavaManager::discover()
{
    if (m_busy) return;
    m_busy = true; m_message = "Looking for Java runtimes…"; emit changed();
    const auto cfg = Prism::readConfig(m_model->dataDir() + "/prismlauncher.cfg");
    QString managed = cfg.value("JavaDir", "java");
    if (QDir::isRelativePath(managed)) managed = m_model->dataDir() + "/" + managed;
    QStringList roots{managed, installRoot(), QDir::homePath() + "/.sdkman/candidates/java", QDir::homePath() + "/.jdks"};
#if defined(Q_OS_WIN)
    const QString programFiles = QDir::fromNativeSeparators(qEnvironmentVariable("ProgramFiles"));
    for (const char *vendor : {"Eclipse Adoptium", "Java", "Microsoft", "Zulu", "BellSoft", "Amazon Corretto", "Semeru"})
        roots.append(programFiles + "/" + vendor);
#elif defined(Q_OS_MACOS)
    roots << "/Library/Java/JavaVirtualMachines" << QDir::homePath() + "/Library/Java/JavaVirtualMachines";
    // Homebrew's opt/ entries are links; the folders they point to are searched.
    for (const QString base : {"/opt/homebrew/opt", "/usr/local/opt"})
        for (const QString &dir : QDir(base).entryList({"openjdk*"}, QDir::Dirs))
            roots.append(QFileInfo(base + "/" + dir).canonicalFilePath());
#else
    roots << "/usr/lib/jvm" << "/usr/lib64/jvm";
    // FreeBSD ports install OpenJDK as /usr/local/openjdk<N>.
    for (const QString &dir : QDir("/usr/local").entryList({"openjdk*", "linux-*jdk*"}, QDir::Dirs))
        roots.append("/usr/local/" + dir);
#endif
    QStringList paths{cfg.value("JavaPath"), QStandardPaths::findExecutable("java"), qEnvironmentVariable("JAVA_HOME") + "/bin/java"};
    auto *watcher = new QFutureWatcher<QVariantList>(this);
    connect(watcher, &QFutureWatcher<QVariantList>::finished, this, [this, watcher] {
        m_runtimes = watcher->result(); watcher->deleteLater(); finish(QString::number(m_runtimes.size()) + " Java runtimes found.");
    });
    watcher->setFuture(QtConcurrent::run([roots, paths]() mutable {
        for (const auto &root : roots) {
            QDirIterator it(root, {"java", "java.exe"}, QDir::Files, QDirIterator::Subdirectories);
            int files = 0;
            while (it.hasNext() && ++files <= 100) paths.append(it.next());
        }
        QSet<QString> seen; QVariantList result;
        for (const auto &path : paths) {
            const QString canonical = QFileInfo(path).canonicalFilePath();
            if (canonical.isEmpty() || seen.contains(canonical) || !QFileInfo(path).isExecutable()) continue;
            seen.insert(canonical); const auto runtime = JavaRuntime::probe(canonical);
            if (!runtime.contains("error")) result.append(runtime);
        }
        return result;
    }));
}
void JavaManager::test(const QString &path, const QString &arguments, int minMemory, int maxMemory)
{
    if (m_busy) return;
    if (!QFileInfo(path).isExecutable() || minMemory < 256 || maxMemory < minMemory || maxMemory > 262144) { finish("Select Java and a valid memory range first."); return; }
    m_busy = true; m_message = "Testing Java with these memory settings and arguments…"; emit changed();
    auto args = QProcess::splitCommand(arguments);
    args << "-Xms" + QString::number(minMemory) + "m" << "-Xmx" + QString::number(maxMemory) + "m";
    auto *watcher = new QFutureWatcher<QVariantMap>(this);
    connect(watcher, &QFutureWatcher<QVariantMap>::finished, this, [this, watcher] {
        const auto result = watcher->result(); watcher->deleteLater();
        finish(result.contains("error") ? result.value("error").toString() : "Java test passed · " + result.value("label").toString());
    });
    watcher->setFuture(QtConcurrent::run(JavaRuntime::probe, path, args));
}
void JavaManager::download(int major)
{
    if (m_busy) return;
    if (!QList<int>{8, 17, 21, 25}.contains(major)) { finish("Choose a supported Java version."); return; }
    const QString cpu = QSysInfo::currentCpuArchitecture();
    const QString arch = cpu == "x86_64" ? "x64" : cpu == "arm64" ? "aarch64" : cpu == "i386" ? "x86" : "";
#if defined(Q_OS_WIN)
    const QString os = "windows";
#elif defined(Q_OS_MACOS)
    const QString os = "mac";
#elif defined(Q_OS_LINUX)
    // musl systems such as Alpine need Temurin's separate build.
    const QString os = QFileInfo::exists("/etc/alpine-release") ? "alpine-linux" : "linux";
#else
    const QString os; // Temurin has no FreeBSD builds.
#endif
    if (os.isEmpty()) {
        finish("Eclipse Temurin has no builds for this system. Install OpenJDK from your packages (for example: pkg install openjdk21).");
        return;
    }
    if (arch.isEmpty()) { finish("Automatic downloads are not available for this CPU."); return; }
    if (!QDir().mkpath(installRoot())) { finish("Cannot create the Java downloads folder."); return; }
    m_busy = true; m_progress = 0; m_message = "Finding Eclipse Temurin " + QString::number(major) + "…"; emit changed();
    QUrl url(m_api.toString() + "/assets/latest/" + QString::number(major) + "/hotspot");
    QUrlQuery query; query.addQueryItem("architecture", arch); query.addQueryItem("os", os); query.addQueryItem("image_type", "jre"); query.addQueryItem("vendor", "eclipse"); url.setQuery(query);
    QNetworkRequest request(url); request.setTransferTimeout(20000); request.setRawHeader("User-Agent", "Prismarine/0.4.0");
    auto *reply = m_network.get(request);
    connect(reply, &QNetworkReply::finished, this, [this, reply, major] {
        reply->deleteLater();
        const auto doc = QJsonDocument::fromJson(reply->readAll());
        const auto package = (doc.array().isEmpty() ? QJsonObject() : doc.array().first().toObject()).value("binary").toObject().value("package").toObject();
        const QUrl link(package.value("link").toString()); const QByteArray checksum = package.value("checksum").toString().toLatin1().toLower();
        if (reply->error() != QNetworkReply::NoError || !QRegularExpression("^[a-f0-9]{64}$").match(QString::fromLatin1(checksum)).hasMatch()
            || (link.scheme() != "https" && !(m_api.scheme() == "http" && link.scheme() == "http"))) { finish("Could not find a verified Java download for this platform."); return; }
        auto staging = std::make_shared<QTemporaryDir>(installRoot() + "/.download-XXXXXX");
        auto file = std::make_shared<QFile>(staging->path() + "/runtime.archive");
        if (!staging->isValid() || !file->open(QIODevice::WriteOnly)) { finish("Cannot prepare the Java download."); return; }
        auto hash = std::make_shared<QCryptographicHash>(QCryptographicHash::Sha256);
        auto bytes = std::make_shared<qint64>(0);
        QNetworkRequest req(link); req.setTransferTimeout(30000); req.setRawHeader("User-Agent", "Prismarine/0.4.0");
        auto *download = m_network.get(req); m_message = "Downloading Eclipse Temurin…"; emit changed();
        connect(download, &QNetworkReply::readyRead, this, [download, file, hash, bytes] {
            const auto data = download->readAll(); *bytes += data.size();
            if (*bytes > 512 * 1024 * 1024 || file->write(data) != data.size()) { download->abort(); return; }
            hash->addData(data);
        });
        connect(download, &QNetworkReply::downloadProgress, this, [this](qint64 received, qint64 total) { m_progress = total > 0 ? double(received) / total : 0; emit changed(); });
        connect(download, &QNetworkReply::finished, this, [this, download, file, hash, checksum, staging, major] {
            file->close(); download->deleteLater();
            if (download->error() != QNetworkReply::NoError || hash->result().toHex() != checksum) { finish("Java download or checksum verification failed. Nothing was installed."); return; }
            m_message = "Unpacking verified Java runtime…"; emit changed();
            const QString destination = installRoot() + "/temurin-" + QString::number(major) + "-" + QUuid::createUuid().toString(QUuid::Id128).left(8);
            auto *watcher = new QFutureWatcher<QString>(this);
            connect(watcher, &QFutureWatcher<QString>::finished, this, [this, watcher] {
                const QString error = watcher->result(); watcher->deleteLater();
                if (!error.isEmpty()) { finish(error); return; }
                finish("Java installed."); discover();
            });
            watcher->setFuture(QtConcurrent::run([staging, file, destination] {
                const QString target = staging->path() + "/runtime";
                const auto error = JavaRuntime::unpack(file->fileName(), target);
                if (!error.isEmpty()) return error;
                if (!QDir().rename(target, destination)) return QString("Cannot finish installing Java.");
                return QString();
            }));
        });
    });
}
