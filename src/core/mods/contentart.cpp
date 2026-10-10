#include "contentart.h"
#include "archivereader.h"
#include <QBuffer>
#include <QImageReader>
#include <QImage>
#include <QDir>
#include <QFile>

QString ContentArt::fromBytes(const QByteArray &bytes)
{
    if (bytes.isEmpty() || bytes.size() > 2 * 1024 * 1024) return {};
    QBuffer input; input.setData(bytes); input.open(QIODevice::ReadOnly);
    QImageReader reader(&input);
    const auto size = reader.size();
    if (!size.isValid() || size.width() > 2048 || size.height() > 2048) return {};
    auto image = reader.read();
    if (image.isNull()) return {};
    if (image.width() > 128 || image.height() > 128)
        image = image.scaled(128, 128, Qt::KeepAspectRatio, Qt::SmoothTransformation);
    QByteArray png; QBuffer output(&png); output.open(QIODevice::WriteOnly);
    if (!image.save(&output, "PNG")) return {};
    return "data:image/png;base64," + QString::fromLatin1(png.toBase64());
}
QString ContentArt::fromArchive(const QString &path, const QStringList &names)
{
    const auto files = Mods::readArchiveFiles(path, names);
    for (const auto &name : names) {
        const auto image = fromBytes(files.value(name));
        if (!image.isEmpty()) return image;
    }
    return {};
}
QString ContentArt::fromFolder(const QString &path, const QStringList &names)
{
    for (const auto &name : names) {
        const auto clean = QDir::cleanPath(name);
        if (QDir::isAbsolutePath(clean) || clean.startsWith("../")) continue;
        QFile file(path + "/" + clean);
        if (!file.open(QIODevice::ReadOnly) || file.size() > 2 * 1024 * 1024) continue;
        const auto image = fromBytes(file.readAll());
        if (!image.isEmpty()) return image;
    }
    return {};
}
