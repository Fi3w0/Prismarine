#pragma once
#include <QStringList>
namespace Prism {
bool startLauncher(const QString &dataDir, const QStringList &arguments, QString *error);
// A specific Prism program to run, e.g. a Prism built with Prismarine's patch that keeps
// launches free of Prism's progress windows. Empty restores the automatic choice.
void setLauncherProgram(const QString &path);
// The program startLauncher will run: the chosen one, a prismlauncher next to
// Prismarine's own executable (bundled builds), then PATH, common native/Nix/Snap
// locations and Linux portable/AppImage directories. Flatpak uses startLauncher.
QString launcherProgram();
// Folder holding generic/<prismarinequiet plugin> (see src/prismquiet), or empty. Prism
// started by Prismarine loads it so launches show none of Prism's windows unless its main
// window is open. Flatpak Prism cannot see it and runs unchanged.
QString quietPluginDir();
// Process id of the Prism the last startLauncher call brought up, or 0 when Prism was already
// running then (the new process only hands the request over and exits). Abort may stop it.
qint64 lastStartedLauncher();
}
