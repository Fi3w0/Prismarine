cmake_minimum_required(VERSION 3.21)
project(Prismarine VERSION 0.4.0 LANGUAGES CXX)

# Qt captures GNUInstallDirs when it creates its deployment support script.
# Windows uses a flat folder; define this before finding Qt so DLLs and qt.conf
# are deployed beside prismarine.exe rather than into a separate bin folder.
if(WIN32)
    set(CMAKE_INSTALL_BINDIR ".")
    set(CMAKE_INSTALL_LIBDIR ".")
endif()

find_package(Qt6 6.6 REQUIRED COMPONENTS Gui Quick QuickControls2 Quick3D Concurrent Network Svg)
find_package(LibArchive REQUIRED)
find_package(OpenSSL 3 REQUIRED COMPONENTS Crypto)
option(PRISMARINE_KEYCHAIN "Enable secure social identity storage with QtKeychain" ON)
if(PRISMARINE_KEYCHAIN)
    find_package(Qt6Keychain QUIET)
endif()
qt_standard_project_setup(REQUIRES 6.6)

add_subdirectory(src/core)
find_package(Qt6 QUIET COMPONENTS Widgets)
if(Qt6Widgets_FOUND)
    add_subdirectory(src/prismquiet)
else()
    message(STATUS "Qt Widgets not found: building without the Prism quiet-launch plugin")
endif()
qt_add_executable(prismarine src/main.cpp)
target_link_libraries(prismarine PRIVATE prismarine_core Qt6::Quick Qt6::QuickControls2 Qt6::Quick3D Qt6::Svg)
include(cmake/Ui.cmake)
include(cmake/Packaging.cmake)

option(PRISMARINE_PACKAGE_CHECK "Build the packaged runtime verification helper" OFF)
if(PRISMARINE_PACKAGE_CHECK)
    qt_add_executable(prismarine_package_check packaging/check-runtime.cpp)
    # CI needs stdout/stderr and an unambiguous process exit code on Windows.
    set_target_properties(prismarine_package_check PROPERTIES WIN32_EXECUTABLE FALSE)
    target_link_libraries(prismarine_package_check PRIVATE prismarine_core)
endif()

include(CTest)
# The tests folder is kept out of the public repository; builds without it skip the tests.
if(BUILD_TESTING AND EXISTS "${PROJECT_SOURCE_DIR}/tests")
    include(cmake/Tests.cmake)
endif()
