# Public regression checks run even when the private tests/ directory is absent.
find_package(Qt6 REQUIRED COMPONENTS Test)
qt_add_executable(application_theme_checks checks/applicationthemetest.cpp src/ui/applicationtheme.cpp src/ui/applicationtheme.h)
target_link_libraries(application_theme_checks PRIVATE prismarine_core Qt6::Test Qt6::Gui)
if(Qt6Widgets_FOUND)
    target_link_libraries(application_theme_checks PRIVATE Qt6::Widgets)
    target_compile_definitions(application_theme_checks PRIVATE PRISMARINE_HAS_WIDGETS=1)
endif()
add_test(NAME application_theme COMMAND application_theme_checks)
set_tests_properties(application_theme PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(navigation_motion_checks checks/navigationmotiontest.cpp)
target_link_libraries(navigation_motion_checks PRIVATE Qt6::Test Qt6::Quick Qt6::QuickControls2 Qt6::Network)
set_source_files_properties(checks/qmldir PROPERTIES QT_RESOURCE_ALIAS "qmldir")
qt_add_resources(navigation_motion_checks check_ui PREFIX "/checks" FILES
    checks/qmldir qml/theme/ColorPalette.qml qml/theme/Colors.qml qml/theme/Typography.qml qml/shell/NavigationRail.qml qml/shell/TopBar.qml
    qml/components/NavButton.qml qml/components/LineIcon.qml qml/components/RoundAvatar.qml
    qml/accounts/AccountSwitcher.qml qml/accounts/SkinAvatar.qml)
qt_add_resources(navigation_motion_checks check_logos PREFIX "/" FILES ${LOGO_ASSETS} ${PROFILE_ASSETS})
add_test(NAME navigation_motion COMMAND navigation_motion_checks)
set_tests_properties(navigation_motion PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")

qt_add_executable(motion_component_checks checks/motioncomponentstest.cpp)
target_link_libraries(motion_component_checks PRIVATE Qt6::Test Qt6::Quick Qt6::QuickControls2)
qt_add_resources(motion_component_checks motion_ui PREFIX "/motion" FILES
    checks/qmldir qml/theme/ColorPalette.qml qml/theme/Colors.qml qml/theme/Typography.qml qml/components/MotionLoader.qml
    qml/components/MotionDialog.qml qml/components/ActionButton.qml qml/components/LineIcon.qml)
add_test(NAME motion_components COMMAND motion_component_checks)
set_tests_properties(motion_components PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")

qt_add_executable(launch_recovery_checks checks/launchrecoverytest.cpp)
target_link_libraries(launch_recovery_checks PRIVATE prismarine_core Qt6::Test Qt6::Quick Qt6::QuickControls2)
qt_add_resources(launch_recovery_checks launch_ui PREFIX "/launch" FILES
    checks/qmldir qml/theme/ColorPalette.qml qml/theme/Colors.qml qml/theme/Typography.qml qml/shell/LaunchOverlay.qml
    qml/components/HeroBackdrop.qml qml/components/InstanceIcon.qml
    qml/components/ActionButton.qml qml/components/TextLink.qml)
add_test(NAME launch_recovery COMMAND launch_recovery_checks)
set_tests_properties(launch_recovery PROPERTIES
    ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")

set_source_files_properties(checks/BrowseFixture.qml PROPERTIES QT_RESOURCE_ALIAS "BrowseFixture.qml")
qt_add_executable(browse_flow_checks checks/browseflowtest.cpp)
target_link_libraries(browse_flow_checks PRIVATE Qt6::Test Qt6::Quick Qt6::QuickControls2)
qt_add_resources(browse_flow_checks browse_ui PREFIX "/browse" FILES
    checks/qmldir checks/BrowseFixture.qml qml/theme/ColorPalette.qml qml/theme/Colors.qml qml/theme/Typography.qml
    qml/pages/BrowsePage.qml qml/browse/BrowseTarget.qml qml/browse/BrowseSidebar.qml
    qml/browse/BrowseResults.qml qml/browse/BrowseProject.qml qml/browse/ProjectContent.qml
    qml/browse/DownloadSelection.qml qml/browse/DownloadQueueBar.qml qml/browse/CurseForgeKeyDialog.qml
    qml/components/MotionDialog.qml qml/components/ActionButton.qml qml/components/SelectBox.qml
    qml/components/InputField.qml qml/components/SideNavItem.qml qml/components/ContentIcon.qml
    qml/components/LineIcon.qml qml/components/NavButton.qml qml/components/TextLink.qml
    qml/components/ToggleSwitch.qml)
qt_add_resources(browse_flow_checks browse_fonts PREFIX "/" FILES ${FONT_ASSETS})
add_test(NAME browse_flow COMMAND browse_flow_checks)
set_tests_properties(browse_flow PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")

qt_add_executable(gamepad_state_checks checks/gamepadstatetest.cpp src/ui/gamepadstate.cpp)
target_include_directories(gamepad_state_checks PRIVATE src)
target_link_libraries(gamepad_state_checks PRIVATE Qt6::Test Qt6::Core)
add_test(NAME gamepad_state COMMAND gamepad_state_checks)

foreach(check navigation values)
    qt_add_executable(gamepad_${check}_checks checks/gamepad${check}test.cpp checks/gamepadfixture.h
        src/ui/gamepadstate.cpp src/ui/spatialfocus.cpp src/ui/gamepadnavigator.cpp)
    target_include_directories(gamepad_${check}_checks PRIVATE src)
    target_link_libraries(gamepad_${check}_checks PRIVATE Qt6::Test Qt6::Quick Qt6::QuickControls2)
    add_test(NAME gamepad_${check} COMMAND gamepad_${check}_checks)
    set_tests_properties(gamepad_${check} PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
endforeach()

qt_add_executable(launcher_mode_checks checks/launchermodetest.cpp)
target_link_libraries(launcher_mode_checks PRIVATE prismarine_core Qt6::Test)
add_test(NAME launcher_mode COMMAND launcher_mode_checks)
set_tests_properties(launcher_mode PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

qt_add_executable(appearance_preferences_checks checks/appearancepreferencestest.cpp)
target_link_libraries(appearance_preferences_checks PRIVATE prismarine_core Qt6::Test Qt6::Quick Qt6::QuickControls2)
qt_add_resources(appearance_preferences_checks appearance_ui PREFIX "/appearance" FILES qml/settings/SettingsDraft.qml)
set_source_files_properties(checks/ColourApplyFixture.qml PROPERTIES QT_RESOURCE_ALIAS "ColourApplyFixture.qml")
qt_add_qml_module(appearance_preferences_checks URI AppearanceChecks VERSION 1.0 QML_FILES
    checks/ColourApplyFixture.qml qml/settings/SettingsDraft.qml qml/settings/ColourEditor.qml qml/settings/PaletteStartingPoints.qml
    qml/components/InputField.qml qml/components/SelectBox.qml qml/components/ActionButton.qml qml/theme/ColorPalette.qml qml/theme/Colors.qml qml/theme/Typography.qml)

add_test(NAME appearance_preferences COMMAND appearance_preferences_checks)
set_tests_properties(appearance_preferences PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")
