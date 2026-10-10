// Pieces every Unix-like system shares: signals and hard links.
#include "native.h"
#include <QFile>
#include <cerrno>
#include <csignal>
#include <cstdio>
#include <sys/stat.h>
#include <unistd.h>

bool Sys::Native::requestClose(qint64 pid)
{
    return ::kill(pid_t(pid), SIGTERM) == 0;
}

bool Sys::Native::terminate(qint64 pid)
{
    return ::kill(pid_t(pid), SIGTERM) == 0;
}

Sys::FileId Sys::Native::fileId(const QString &path)
{
    struct stat info;
    if (::stat(QFile::encodeName(path).constData(), &info) != 0) return {};
    return {quint64(info.st_dev), quint64(info.st_ino), quint64(info.st_nlink), true};
}

bool Sys::Native::hardLink(const QString &existing, const QString &link)
{
    return ::link(QFile::encodeName(existing).constData(), QFile::encodeName(link).constData()) == 0;
}

bool Sys::Native::replaceFile(const QString &from, const QString &to)
{
    return ::rename(QFile::encodeName(from).constData(), QFile::encodeName(to).constData()) == 0;
}
