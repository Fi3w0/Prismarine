#include "gamelog.h"
#include <QRegularExpression>

QVariant GameLogModel::data(const QModelIndex &index, int role) const
{
    if (!index.isValid() || index.row() >= m_lines.size()) return {};
    const Line &line = m_lines.at(index.row());
    return role == LevelRole ? line.level : role == TextRole || role == Qt::DisplayRole ? QVariant(line.text) : QVariant();
}

QHash<int, QByteArray> GameLogModel::roleNames() const
{
    return {{TextRole, "text"}, {LevelRole, "level"}};
}

QString GameLogModel::levelOf(const QString &line)
{
    // Vanilla/Fabric: "[12:00:00] [main/WARN]: ..."; Forge/NeoForge: "[08Oct2026 07:40:30.720] [Render thread/INFO] [logger/]: ...".
    static const QRegularExpression pattern(QStringLiteral(R"(^\[[^\]]*\] \[[^\]]*/(TRACE|DEBUG|INFO|WARN|ERROR|FATAL)\])"));
    const auto match = pattern.match(line);
    if (!match.hasMatch()) return {};
    const QString level = match.captured(1);
    return level == "FATAL" ? QStringLiteral("ERROR") : level == "TRACE" ? QStringLiteral("DEBUG") : level;
}

void GameLogModel::append(const QStringList &lines)
{
    if (lines.isEmpty()) return;
    QString previous = m_lines.isEmpty() ? QStringLiteral("INFO") : m_lines.constLast().level;
    QList<Line> added;
    added.reserve(lines.size());
    for (const QString &text : lines) {
        const QString level = levelOf(text);
        previous = level.isEmpty() ? previous : level;
        added.append({text, previous});
    }
    if (added.size() > MaxLines) added = added.mid(added.size() - MaxLines);
    const int overflow = int(m_lines.size() + added.size()) - MaxLines;
    if (overflow > 0) {
        beginRemoveRows({}, 0, overflow - 1);
        m_lines.remove(0, overflow);
        endRemoveRows();
    }
    beginInsertRows({}, int(m_lines.size()), int(m_lines.size() + added.size() - 1));
    m_lines.append(added);
    endInsertRows();
}

void GameLogModel::clear()
{
    beginResetModel();
    m_lines.clear();
    endResetModel();
}

template <typename Change>
void GameLogFilter::refilter(Change change)
{
#if QT_VERSION >= QT_VERSION_CHECK(6, 10, 0)
    beginFilterChange();
    change();
    endFilterChange(Direction::Rows);
#else
    change();
    invalidateRowsFilter();
#endif
}

void GameLogFilter::setLevel(const QString &level)
{
    if (level == m_level) return;
    refilter([&] { m_level = level; });
    emit filterChanged();
}

void GameLogFilter::setText(const QString &text)
{
    if (text == m_text) return;
    refilter([&] { m_text = text; });
    emit filterChanged();
}

bool GameLogFilter::filterAcceptsRow(int row, const QModelIndex &parent) const
{
    const QModelIndex index = sourceModel()->index(row, 0, parent);
    if (!m_level.isEmpty() && index.data(GameLogModel::LevelRole).toString() != m_level) return false;
    return m_text.isEmpty() || index.data(GameLogModel::TextRole).toString().contains(m_text, Qt::CaseInsensitive);
}
