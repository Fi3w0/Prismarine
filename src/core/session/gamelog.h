#pragma once
#include <QAbstractListModel>
#include <QSortFilterProxyModel>

// Lines of the running game's log with their log4j level.
class GameLogModel : public QAbstractListModel {
    Q_OBJECT
public:
    enum Roles { TextRole = Qt::UserRole + 1, LevelRole };
    struct Line { QString text; QString level; };
    using QAbstractListModel::QAbstractListModel;
    int rowCount(const QModelIndex &parent = {}) const override { return parent.isValid() ? 0 : int(m_lines.size()); }
    QVariant data(const QModelIndex &index, int role) const override;
    QHash<int, QByteArray> roleNames() const override;
    // Appends complete lines, inheriting the previous level for continuations such as stack traces.
    void append(const QStringList &lines);
    void clear();
    const QList<Line> &lines() const { return m_lines; }
    static QString levelOf(const QString &line);
private:
    static constexpr int MaxLines = 5000;
    QList<Line> m_lines;
};

// Level chips and text search over a GameLogModel.
class GameLogFilter : public QSortFilterProxyModel {
    Q_OBJECT
    Q_PROPERTY(QString level READ level WRITE setLevel NOTIFY filterChanged)
    Q_PROPERTY(QString text READ text WRITE setText NOTIFY filterChanged)
public:
    using QSortFilterProxyModel::QSortFilterProxyModel;
    QString level() const { return m_level; }
    QString text() const { return m_text; }
    void setLevel(const QString &level);
    void setText(const QString &text);
signals:
    void filterChanged();
protected:
    bool filterAcceptsRow(int row, const QModelIndex &parent) const override;
private:
    template <typename Change> void refilter(Change change);
    QString m_level, m_text;
};
