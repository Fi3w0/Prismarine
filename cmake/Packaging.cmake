# How Prismarine is installed and packaged on each system.
#
#   Linux/FreeBSD: bin/, share/ (desktop file, icons, AppStream), lib/prismarine/plugins.
#                  Packages use the system's Qt (deb, rpm) or bundle it (AppImage, built in CI).
#   Windows:       a flat folder: prismarine.exe, Qt (windeployqt), plugins/generic.
#   macOS:         Prismarine.app with Qt (macdeployqt) and Contents/PlugIns/generic.
#
# -DPRISMARINE_DEPLOY_QT=ON copies Qt next to the app on install (Windows/macOS packages).
option(PRISMARINE_DEPLOY_QT "Bundle Qt into the install folder (Windows and macOS packages)" OFF)

set(PRISMARINE_LICENSE_FILES LICENSE NOTICE TRADEMARKS.md assets/fonts/OFL.txt)

if(WIN32)
    string(REPLACE "." "," PRISMARINE_VERSION_COMMA "${PROJECT_VERSION},0")
    configure_file(packaging/windows/prismarine.rc.in ${PROJECT_BINARY_DIR}/prismarine.rc @ONLY)
    target_sources(prismarine PRIVATE ${PROJECT_BINARY_DIR}/prismarine.rc)
    set_target_properties(prismarine PROPERTIES WIN32_EXECUTABLE TRUE)
    # A flat folder: Qt's deploy step puts its DLLs beside the executable too.
    set(CMAKE_INSTALL_BINDIR .)
    install(TARGETS prismarine RUNTIME DESTINATION .)
    install(FILES ${PRISMARINE_LICENSE_FILES} DESTINATION licenses)
    install(FILES assets/logos/LICENSE DESTINATION licenses RENAME LOGO-LICENSE)
elseif(APPLE)
    set(icon assets/logos/icons/prismarine.icns)
    set_source_files_properties(${icon} PROPERTIES MACOSX_PACKAGE_LOCATION Resources)
    target_sources(prismarine PRIVATE ${icon})
    set_target_properties(prismarine PROPERTIES
        MACOSX_BUNDLE TRUE
        OUTPUT_NAME Prismarine
        MACOSX_BUNDLE_BUNDLE_NAME Prismarine
        MACOSX_BUNDLE_GUI_IDENTIFIER io.github.fi3w0.prismarine
        MACOSX_BUNDLE_ICON_FILE prismarine.icns
        MACOSX_BUNDLE_SHORT_VERSION_STRING ${PROJECT_VERSION}
        MACOSX_BUNDLE_BUNDLE_VERSION ${PROJECT_VERSION}
        MACOSX_BUNDLE_COPYRIGHT "Copyright (C) Fi3w0. GPL-3.0-only.")
    install(TARGETS prismarine BUNDLE DESTINATION .)
    install(FILES ${PRISMARINE_LICENSE_FILES} DESTINATION Prismarine.app/Contents/Resources/licenses)
    install(FILES assets/logos/LICENSE DESTINATION Prismarine.app/Contents/Resources/licenses RENAME LOGO-LICENSE)
else()
    include(GNUInstallDirs)
    install(TARGETS prismarine RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
    install(FILES ${PRISMARINE_LICENSE_FILES} DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/prismarine)
    install(FILES assets/logos/LICENSE DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/prismarine RENAME LOGO-LICENSE)
    # Reverse-DNS application ID: desktop file, icon, AppStream and the window's app ID agree.
    set(app_id io.github.fi3w0.Prismarine)
    install(FILES packaging/linux/${app_id}.desktop DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
    install(FILES assets/logos/desktop.svg DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps RENAME ${app_id}.svg)
    foreach(size 16 24 32 48 64 128 256 512)
        install(FILES assets/logos/icons/prismarine-${size}.png
                DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/${size}x${size}/apps RENAME ${app_id}.png)
    endforeach()
    configure_file(packaging/linux/${app_id}.metainfo.xml ${PROJECT_BINARY_DIR}/${app_id}.metainfo.xml @ONLY)
    install(FILES ${PROJECT_BINARY_DIR}/${app_id}.metainfo.xml DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo)
endif()

if(PRISMARINE_DEPLOY_QT)
    if(APPLE AND TARGET prismarinequiet)
        # Our generic plugin is loaded by Prism rather than by our QML engine,
        # so explicitly include it when macdeployqt rewrites framework references.
        qt_generate_deploy_qml_app_script(TARGET prismarine OUTPUT_SCRIPT deploy_script
            NO_UNSUPPORTED_PLATFORM_ERROR DEPLOY_TOOL_OPTIONS
            "-executable=Prismarine.app/Contents/PlugIns/prismarine/generic/$<TARGET_FILE_NAME:prismarinequiet>")
    else()
        qt_generate_deploy_qml_app_script(TARGET prismarine OUTPUT_SCRIPT deploy_script NO_UNSUPPORTED_PLATFORM_ERROR)
    endif()
    install(SCRIPT ${deploy_script})
endif()

# Packages: cpack -G DEB / RPM / TGZ / ZIP.
set(CPACK_PACKAGE_NAME prismarine)
set(CPACK_PACKAGE_VENDOR Fi3w0)
set(CPACK_PACKAGE_CONTACT "Fi3w0 <https://github.com/Fi3w0>")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Minecraft library and instance manager for Prism Launcher")
set(CPACK_PACKAGE_HOMEPAGE_URL https://github.com/Fi3w0)
set(CPACK_RESOURCE_FILE_LICENSE ${PROJECT_SOURCE_DIR}/LICENSE)
set(CPACK_STRIP_FILES ON)
set(CPACK_DEBIAN_FILE_NAME DEB-DEFAULT)
set(CPACK_DEBIAN_PACKAGE_SECTION games)
set(CPACK_DEBIAN_PACKAGE_SHLIBDEPS ON)
file(STRINGS ${PROJECT_SOURCE_DIR}/packaging/linux/debian-runtime-depends.txt runtime_packages REGEX "^[a-z0-9]")
list(JOIN runtime_packages ", " runtime_depends)
set(CPACK_DEBIAN_PACKAGE_DEPENDS "${runtime_depends}")
set(CPACK_DEBIAN_PACKAGE_RECOMMENDS prismlauncher)
set(CPACK_RPM_FILE_NAME RPM-DEFAULT)
set(CPACK_RPM_PACKAGE_LICENSE GPL-3.0-only)
set(CPACK_RPM_PACKAGE_GROUP Amusements/Games)
# QML modules and the SVG image plugin are loaded at run time, so automatic requirements miss them.
set(CPACK_RPM_PACKAGE_REQUIRES "qt6-qtdeclarative, qt6-qtquick3d, qt6-qtsvg")
set(CPACK_RPM_PACKAGE_SUGGESTS prismlauncher)
set(CPACK_RPM_EXCLUDE_FROM_AUTO_FILELIST_ADDITION /usr/share/applications /usr/share/icons /usr/share/metainfo /usr/share/licenses)
include(CPack)
