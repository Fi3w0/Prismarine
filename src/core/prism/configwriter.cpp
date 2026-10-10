#include "configwriter.h"
#include <QFile>
#include <QSaveFile>
#include <QSet>
#include <QRegularExpression>

static QString encode(const QVariant &value)
{
    QString text = value.toString();
    // Qt's INI reader treats unquoted commas as a string list.
    if (text.startsWith('@')) text.prepend('@');
    text.replace("\\", "\\\\"); text.replace("\"", "\\\"");
    return "\"" + text + "\"";
}

bool Prism::writeConfig(const QString &path, const QVariantMap &updates, QString *error, bool requireExisting)
{
    const auto fail = [&](const QString &message) { if (error) *error = message; return false; };
    for (auto it = updates.cbegin(); it != updates.cend(); ++it) {
        if (!QRegularExpression("^[A-Za-z0-9_.-]+$").match(it.key()).hasMatch()
            || it.value().toString().contains(QRegularExpression("[\\r\\n\\x{0000}]")))
            return fail("Invalid settings key or value.");
    }
    QFile original(path);
    const bool existed = original.exists();
    if (!existed && requireExisting) return fail("This settings file is no longer available.");
    if (existed && !original.open(QIODevice::ReadOnly)) return fail("Could not read settings.");
    const QByteArray previous = existed ? original.readAll() : QByteArray();
    original.close();
    QStringList lines = QString::fromUtf8(previous).split('\n');
    const bool hasSections = QRegularExpression("(?m)^\\s*\\[").match(QString::fromUtf8(previous)).hasMatch();
    bool general = !hasSections;
    bool foundGeneral = !hasSections;
    int insertion = lines.size();
    QSet<QString> replaced;
    for (int i = 0; i < lines.size(); ++i) {
        const QString trimmed = lines[i].trimmed();
        if (trimmed.startsWith('[')) {
            if (general) insertion = i;
            general = trimmed == "[General]";
            if (general) { foundGeneral = true; insertion = lines.size(); }
            continue;
        }
        if (!general || trimmed.startsWith('#') || trimmed.startsWith(';')) continue;
        const int eq = lines[i].indexOf('=');
        const QString key = lines[i].left(eq).trimmed();
        if (eq > 0 && updates.contains(key)) {
            lines[i] = key + "=" + encode(updates.value(key));
            replaced.insert(key);
        }
    }
    if (!foundGeneral) { lines.append("[General]"); insertion = lines.size(); }
    for (auto it = updates.cbegin(); it != updates.cend(); ++it)
        if (!replaced.contains(it.key())) lines.insert(insertion++, it.key() + "=" + encode(it.value()));
    QFile check(path);
    if (check.exists() != existed || (existed && (!check.open(QIODevice::ReadOnly) || check.readAll() != previous)))
        return fail("Settings changed while saving. Reload and try again.");
    const QByteArray bytes = lines.join('\n').toUtf8();
    QSaveFile output(path);
    if (!output.open(QIODevice::WriteOnly) || output.write(bytes) != bytes.size() || !output.commit())
        return fail("Could not save settings: " + output.errorString());
    return true;
}
