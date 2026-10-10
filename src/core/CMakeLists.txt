# UI-independent services and Qt models, shared by the app and fixture tests.
add_library(prismarine_core STATIC
    library/instance.h
    library/instancemodel.h library/instancemodel.cpp
    library/librarygroups.cpp library/libraryqueries.cpp library/instancecommands.cpp
    library/displayformat.h library/displayformat.cpp
    library/playtimehistory.h library/playtimehistory.cpp
    library/altlaunch.h library/altlaunch.cpp
    prism/configreader.h prism/configreader.cpp
    prism/paths.h prism/paths.cpp
    prism/instancereader.h prism/instancereader.cpp
    prism/accountreader.h prism/accountreader.cpp
    prism/launcherbridge.h prism/launcherbridge.cpp
    instance/instancedetails.h instance/instancedetails.cpp
    instance/instancecontents.h instance/contentscanner.cpp
    instance/contentactions.cpp instance/modprofiles.cpp
    mods/modhealth.h mods/modhealth.cpp
    mods/archivereader.h mods/archivereader.cpp
    mods/contentart.h mods/contentart.cpp
    mods/modmetadata.h mods/modmetadata.cpp
    preferences/apppreferences.h preferences/apppreferences.cpp
    prism/configwriter.h prism/configwriter.cpp
    settings/launchsettings.h settings/launchsettings.cpp settings/networksettings.h settings/networksettings.cpp settings/desktopintegration.h settings/desktopintegration.cpp
    settings/javamanager.h settings/javamanager.cpp settings/javaarchive.cpp
    creation/instancecreator.h creation/instancecreator.cpp creation/instanceediting.cpp
    accounts/accountmanager.h accounts/accountmanager.cpp
    install/contentinstaller.h install/dependencyresolver.cpp install/curseforgeinstall.cpp install/verifieddownload.cpp install/installedindex.cpp
    install/modupdater.h install/modupdater.cpp
    packs/packimporter.h packs/packimporter.cpp packs/packexporter.h packs/packexporter.cpp packs/packextractor.cpp packs/packdownloads.cpp
    catalog/projectdetails.cpp catalog/curseforge.h catalog/curseforge.cpp catalog/curseforgecatalog.cpp
    catalog/modcatalog.h catalog/modcatalog.cpp
    session/gamelog.h session/gamelog.cpp session/gamesession.h session/gamesession.cpp
    session/crashanalyzer.h session/crashanalyzer.cpp session/launchprogress.h session/launchprogress.cpp session/gamemonitor.h session/gamemonitor.cpp
    news/newsfeed.h news/newsfeed.cpp
    servers/nbt.h servers/nbt.cpp servers/serverlist.h servers/serverlist.cpp
    social/crypto.h social/crypto.cpp social/mojangkeys.h
    social/socialprotocol.h social/socialprotocol.cpp
    social/identitystore.h social/identitystore.cpp
    social/socialmanager.h social/socialmanager.cpp social/minecraftlink.cpp
    social/landiscovery.h social/landiscovery.cpp
    storage/storagemanager.h storage/storagemanager.cpp storage/contentsharing.cpp
    install/droppedfiles.h install/droppedfiles.cpp
)
target_include_directories(prismarine_core PUBLIC "${PROJECT_SOURCE_DIR}/src")
target_link_libraries(prismarine_core PUBLIC Qt6::Gui Qt6::Concurrent Qt6::Network
    PRIVATE LibArchive::LibArchive OpenSSL::Crypto)
if(PRISMARINE_KEYCHAIN AND TARGET qt6keychain)
    target_link_libraries(prismarine_core PRIVATE qt6keychain)
    target_compile_definitions(prismarine_core PRIVATE PRISMARINE_HAS_KEYCHAIN=1)
else()
    message(STATUS "QtKeychain unavailable: social identity creation/unlocking disabled")
endif()

# Operating system backend for processes, machine load, GPUs and hard links (src/core/system).
target_sources(prismarine_core PRIVATE system/system.h system/native.h system/archivefiles.h system/system_common.cpp)
if(WIN32)
    target_sources(prismarine_core PRIVATE system/system_windows.cpp)
    target_link_libraries(prismarine_core PRIVATE pdh dxgi psapi)
elseif(APPLE)
    target_sources(prismarine_core PRIVATE system/system_unix.cpp system/system_macos.cpp)
    target_link_libraries(prismarine_core PRIVATE "-framework IOKit" "-framework CoreFoundation")
elseif(CMAKE_SYSTEM_NAME STREQUAL "Linux")
    target_sources(prismarine_core PRIVATE system/system_unix.cpp system/system_linux.cpp)
elseif(CMAKE_SYSTEM_NAME STREQUAL "FreeBSD")
    target_sources(prismarine_core PRIVATE system/system_unix.cpp system/system_freebsd.cpp)
else()
    message(FATAL_ERROR "Prismarine has no system backend for ${CMAKE_SYSTEM_NAME} (see src/core/system)")
endif()
