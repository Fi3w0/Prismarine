cmake_minimum_required(VERSION 3.21)
project(Prismarine VERSION 0.5.0 LANGUAGES CXX)
add_compile_definitions(PRISMARINE_VERSION="${PROJECT_VERSION}")

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
qt_add_executable(prismarine src/main.cpp src/ui/applicationtheme.cpp src/ui/applicationtheme.h
    src/ui/gamepadstate.cpp src/ui/gamepadstate.h src/ui/spatialfocus.cpp src/ui/spatialfocus.h
    src/ui/gamepadnavigator.cpp src/ui/gamepadnavigator.h src/ui/gamepadinput.cpp src/ui/gamepadinput.h)
target_link_libraries(prismarine PRIVATE prismarine_core Qt6::Quick Qt6::QuickControls2 Qt6::Quick3D Qt6::Svg)
if(Qt6Widgets_FOUND)
    target_link_libraries(prismarine PRIVATE Qt6::Widgets)
    target_compile_definitions(prismarine PRIVATE PRISMARINE_HAS_WIDGETS=1)
endif()
# Optional: controller navigation. Without SDL the app simply has no controller support.
option(PRISMARINE_CONTROLLER "Enable controller navigation with SDL2" ON)
# Release builds turn this on, so a missing SDL2 fails instead of quietly losing the feature.
option(PRISMARINE_REQUIRE_CONTROLLER "Fail the configure step when SDL2 is not found" OFF)
if(PRISMARINE_CONTROLLER)
    find_package(SDL2 CONFIG QUIET)
    # System packages provide the shared target; vcpkg's static triplets provide only the other.
    if(TARGET SDL2::SDL2)
        set(prismarine_sdl_target SDL2::SDL2)
    elseif(TARGET SDL2::SDL2-static)
        set(prismarine_sdl_target SDL2::SDL2-static)
    endif()
    if(prismarine_sdl_target)
        target_link_libraries(prismarine PRIVATE ${prismarine_sdl_target})
        target_compile_definitions(prismarine PRIVATE PRISMARINE_HAS_SDL=1)
    elseif(PRISMARINE_REQUIRE_CONTROLLER)
        message(FATAL_ERROR "SDL2 was not found, and PRISMARINE_REQUIRE_CONTROLLER is on")
    else()
        message(STATUS "SDL2 not found: building without controller navigation")
    endif()
endif()
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
if(BUILD_TESTING)
    include(cmake/Checks.cmake)
endif()
# Additional private suites are available in local checkouts with tests/.
if(BUILD_TESTING AND EXISTS "${PROJECT_SOURCE_DIR}/tests")
    include(cmake/Tests.cmake)
endif()
