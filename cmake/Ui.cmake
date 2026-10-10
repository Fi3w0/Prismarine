# Types use one QML module. Feature folders keep edit locations clear, while
# aliases let components refer to each other without relative-path imports.
set(QML_SOURCES
    qml/pages/FriendsPage.qml qml/social/SocialIdentityCard.qml qml/social/SocialFriendsCard.qml qml/social/SocialInvitesCard.qml
    qml/accounts/SkinParts.js qml/accounts/SkinMesh.qml qml/accounts/SkinScene.qml qml/accounts/FlatSkin.qml qml/accounts/ProfileDetails.qml qml/accounts/SkinLibrary.qml
    qml/library/LibraryFact.qml qml/library/LibraryAction.qml
    qml/accounts/SkinAvatar.qml qml/accounts/AccountSwitcher.qml
    qml/browse/DownloadSelection.qml qml/browse/DownloadQueueBar.qml qml/browse/ProjectContent.qml
    qml/components/ContentIcon.qml qml/components/SideNavItem.qml qml/components/TextLink.qml qml/components/ConfirmDialog.qml
    qml/pages/SessionPage.qml qml/session/MemoryGraph.qml qml/session/HardwareView.qml qml/session/LiveLog.qml qml/session/CrashHelp.qml qml/components/TickBox.qml
    qml/shell/NavigationHistory.qml qml/shell/ActivityBar.qml qml/shell/ExportDialog.qml
    qml/components/MotionLoader.qml qml/components/MotionDialog.qml
    qml/components/RenameTarget.qml qml/shell/RenameInstanceDialog.qml
    qml/settings/LaunchSettingsForm.qml qml/settings/JavaRuntimePicker.qml qml/settings/InstanceSettingsDialog.qml
    qml/browse/BrowseSidebar.qml qml/browse/CurseForgeKeyDialog.qml
    qml/browse/InstallReviewDialog.qml
    qml/accounts/SkinPreview.qml qml/shell/PackImportDialog.qml
    qml/Main.qml qml/theme/Colors.qml
    qml/shell/NavigationRail.qml qml/shell/NewInstanceDialog.qml qml/shell/DuplicateDialog.qml qml/shell/Toast.qml qml/shell/FirstRunScreen.qml
    qml/pages/HomePage.qml qml/pages/LibraryPage.qml qml/pages/InstancePage.qml
    qml/pages/SettingsPage.qml qml/pages/AccountsPage.qml qml/pages/BrowsePage.qml
    qml/components/ToggleSwitch.qml qml/components/InputField.qml qml/components/SelectBox.qml
    qml/components/ActionButton.qml qml/components/Chip.qml
    qml/components/HeroBackdrop.qml
    qml/components/CoverArt.qml qml/components/InstanceIcon.qml
    qml/components/InstanceCard.qml qml/components/LineIcon.qml qml/components/NavButton.qml
    qml/library/LibrarySidebarEntry.qml
    qml/library/LibrarySidebar.qml qml/library/LibraryBrowser.qml qml/library/LibraryDetails.qml
    qml/instance/InstanceHero.qml qml/instance/InstanceTabs.qml
    qml/instance/InstanceOverview.qml qml/instance/InstanceMods.qml
    qml/instance/InstanceScreenshots.qml qml/instance/InstanceFiles.qml qml/instance/DatapackDialog.qml qml/instance/ContentUpdates.qml
    qml/instance/InstanceInfoPanel.qml qml/instance/InstanceQuickSettings.qml
    qml/instance/InstalledModsPanel.qml qml/instance/InstanceNotesPanel.qml
    qml/home/HomeHero.qml
    qml/home/HomeNews.qml
    qml/home/HomePlaytime.qml
    qml/home/HomeStats.qml
    qml/home/HomeWorlds.qml
    qml/home/RecentInstances.qml
    qml/settings/AboutPanel.qml
    qml/settings/AccentPicker.qml
    qml/settings/ThemePicker.qml
    qml/settings/AppearancePreview.qml
    qml/settings/AppearanceSwitches.qml
    qml/settings/LibraryPreferences.qml
    qml/settings/SettingsSidebar.qml
    qml/library/InstanceSearch.qml
    qml/library/LibraryCoverGrid.qml
    qml/library/LibraryEmptyState.qml
    qml/library/LibraryFilters.qml
    qml/library/LibraryRows.qml
    qml/library/LibraryToolbar.qml
    qml/instance/ModRow.qml
    qml/instance/InstanceServers.qml
    qml/browse/BrowseProject.qml
    qml/browse/BrowseResults.qml
    qml/components/ThemedMenu.qml qml/components/ThemedMenuItem.qml qml/components/FileDropTarget.qml
    qml/shell/DropOverlay.qml qml/shell/DropInstallDialog.qml qml/shell/GroupNameDialog.qml qml/shell/MoveToGroupDialog.qml
    qml/library/InstanceContextMenu.qml qml/components/DialogActions.qml qml/components/TextPromptDialog.qml
    qml/instance/ModHealthPanel.qml qml/instance/ModProfilesButton.qml
    qml/settings/NetworkSettingsForm.qml qml/settings/ExperimentalPanel.qml qml/home/HomeServers.qml qml/shell/CommandPalette.qml qml/shell/ArtworkDialog.qml qml/shell/LaunchOverlay.qml
    qml/settings/StoragePanel.qml qml/settings/StorageBar.qml qml/settings/StorageInstanceRow.qml
)
foreach(file IN LISTS QML_SOURCES)
    get_filename_component(name "${file}" NAME)
    set_source_files_properties("${file}" PROPERTIES QT_RESOURCE_ALIAS "${name}")
endforeach()
set_source_files_properties(qml/theme/Colors.qml PROPERTIES QT_QML_SINGLETON_TYPE TRUE)
qt_add_qml_module(prismarine URI Prismarine VERSION 1.0 QML_FILES ${QML_SOURCES})
set(LOGO_ASSETS assets/logos/shard-o.svg assets/logos/shard-k.svg assets/logos/desktop.svg)
# Outfit ships as static weights: Qt registers the variable font only as "Outfit Thin".
set(FONT_ASSETS assets/fonts/Outfit-Regular.ttf assets/fonts/Outfit-Medium.ttf
    assets/fonts/Outfit-SemiBold.ttf assets/fonts/Outfit-Bold.ttf
    assets/fonts/MarcellusSC.ttf assets/fonts/Silkscreen.ttf)
qt_add_resources(prismarine branding PREFIX "/" FILES ${FONT_ASSETS} ${LOGO_ASSETS})
