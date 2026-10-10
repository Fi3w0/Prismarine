#include "configreader.h"
#include <QFile>
#include <QTextStream>

namespace Prism {
// Prism's .cfg files are simple INI. Read them by hand: QSettings would turn
// names containing commas into lists.
QHash<QString, QString> readConfig(const QString &file)
{
    QHash<QString, QString> values;
    QFile f(file);
    if (!f.open(QIODevice::ReadOnly | QIODevice::Text))
        return values;
    QTextStream in(&f);
    bool general = true;
    while (!in.atEnd()) {
        const QString line = in.readLine();
        const QString trimmed = line.trimmed();
        if (trimmed.startsWith('[')) { general = trimmed == "[General]"; continue; }
        if (!general || trimmed.startsWith('#') || trimmed.startsWith(';')) continue;
        const int eq = line.indexOf(u'=');
        if (eq <= 0 || line.startsWith(u'['))
            continue;
        QString value = line.mid(eq + 1);
        if (value.size() >= 2 && value.startsWith(u'"') && value.endsWith(u'"')) {
            value = value.mid(1, value.size() - 2);
            QString decoded;
            for (int i = 0; i < value.size(); ++i) {
                if (value[i] == '\\' && i + 1 < value.size()) {
                    const QChar next = value[++i];
                    if (next == 'n') decoded += '\n';
                    else if (next == 't') decoded += '\t';
                    else if (next == 'r') decoded += '\r';
                    else decoded += next;
                } else decoded += value[i];
            }
            value = decoded;
        }
        if (value.startsWith("@@")) value.remove(0, 1);
        values.insert(line.left(eq).trimmed(), value);
    }
    return values;
}

}
