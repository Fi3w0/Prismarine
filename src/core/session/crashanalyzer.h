#pragma once
#include <QString>
#include <QVariantList>
#include <QVariantMap>

// Reads a game log or crash report and explains the usual causes of a crash in plain words.
// Each finding: {kind, title, detail, mods (ids), action: "mods" | "settings" | "browse" | "", query}.
namespace CrashAnalyzer {
QVariantList analyze(const QString &text);
// True when the text shows the game actually crashed, not just warnings.
bool crashed(const QString &text);
// Latest log plus the newest crash report, when that report comes from the same session.
// With sinceMs, only files written at or after that time count.
QString collect(const QString &gameDir, qint64 sinceMs = 0, QString *reportPath = nullptr);
}
