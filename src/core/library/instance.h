#pragma once
#include <QString>

// One Prism Launcher instance, read from its folder.
struct Instance {
    QString id;            // folder name, what `prismlauncher --launch` expects
    QString path;
    QString name;
    QString iconUrl;       // file:// URL or empty (QML draws a letter tile)
    QString mcVersion;
    QString loader;        // Vanilla, Fabric, Quilt, Forge, NeoForge
    QString loaderVersion;
    QString screenshotUrl; // newest screenshot of the instance, if any
    QString memory;
    QString accountId;
    // Set for multi-account copies made by AltLaunch: the source instance and account.
    QString altOf, altAccount;
    int mods = 0;
    qint64 playedSecs = 0;
    qint64 lastLaunchMs = 0;
};

