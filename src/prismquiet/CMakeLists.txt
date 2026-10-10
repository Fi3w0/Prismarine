# Plugin loaded into Prism Launcher (see prismquiet.cpp). Prism is a Qt Widgets app,
# so the plugin needs Widgets even though Prismarine itself does not.
qt_add_plugin(prismarinequiet SHARED CLASS_NAME PrismQuietPlugin prismquiet.cpp)
target_link_libraries(prismarinequiet PRIVATE Qt6::Gui Qt6::Widgets)
# Qt looks for generic plugins in <plugin path>/generic.
set_target_properties(prismarinequiet PROPERTIES LIBRARY_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/plugins/generic"
    RUNTIME_OUTPUT_DIRECTORY "${PROJECT_BINARY_DIR}/plugins/generic")
# Found by Prism::quietPluginDir(): beside the exe (Windows), in the bundle (macOS), or lib/ (Unix).
if(WIN32)
    install(TARGETS prismarinequiet RUNTIME DESTINATION plugins/generic LIBRARY DESTINATION plugins/generic)
elseif(APPLE)
    install(TARGETS prismarinequiet LIBRARY DESTINATION Prismarine.app/Contents/PlugIns/generic)
else()
    install(TARGETS prismarinequiet LIBRARY DESTINATION lib/prismarine/plugins/generic)
endif()
