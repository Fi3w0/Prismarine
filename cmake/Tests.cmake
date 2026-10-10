find_package(Qt6 REQUIRED COMPONENTS Test)
qt_add_executable(prismarine_tests tests/applicationtest.cpp)
target_link_libraries(prismarine_tests PRIVATE prismarine_core Qt6::Test
    Qt6::Quick Qt6::QuickControls2 LibArchive::LibArchive)
set_source_files_properties(tests/qmldir PROPERTIES QT_RESOURCE_ALIAS "qmldir")
qt_add_resources(prismarine_tests test_ui PREFIX "/ui" FILES ${QML_SOURCES} tests/qmldir)
qt_add_resources(prismarine_tests test_branding PREFIX "/" FILES ${FONT_ASSETS} ${LOGO_ASSETS})
add_test(NAME application COMMAND prismarine_tests)
set_tests_properties(application PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software")

qt_add_executable(catalog_tests tests/catalogtest.cpp)
target_link_libraries(catalog_tests PRIVATE prismarine_core Qt6::Test)
add_test(NAME catalog COMMAND catalog_tests)

qt_add_executable(native_tests tests/nativetest.cpp)
target_link_libraries(native_tests PRIVATE prismarine_core Qt6::Test LibArchive::LibArchive)
add_test(NAME native COMMAND native_tests)

qt_add_executable(content_tests tests/contenttest.cpp)
target_link_libraries(content_tests PRIVATE prismarine_core Qt6::Test LibArchive::LibArchive)
add_test(NAME content COMMAND content_tests)

qt_add_executable(system_tests tests/systemtest.cpp)
target_link_libraries(system_tests PRIVATE prismarine_core Qt6::Test)
add_test(NAME system COMMAND system_tests)

qt_add_executable(social_tests tests/socialtest.cpp)
target_link_libraries(social_tests PRIVATE prismarine_core Qt6::Test OpenSSL::Crypto)
add_test(NAME social COMMAND social_tests)

if(TARGET prismarinequiet)
    qt_add_executable(prismquiet_tests tests/prismquiettest.cpp)
    target_link_libraries(prismquiet_tests PRIVATE Qt6::Test Qt6::Widgets)
    target_compile_definitions(prismquiet_tests PRIVATE PRISMQUIET_PLUGIN_DIR="${PROJECT_BINARY_DIR}/plugins")
    add_dependencies(prismquiet_tests prismarinequiet)
    add_test(NAME prismquiet COMMAND prismquiet_tests)
    set_tests_properties(prismquiet PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
endif()
