cmake_minimum_required(VERSION 3.22)
project(omarchy-software VERSION 0.1.0 LANGUAGES CXX)
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 6.4 REQUIRED COMPONENTS Core Gui Quick Qml QuickControls2 Network)

find_program(CARGO cargo REQUIRED)

# ── Core ────────────────────────────────────────────────────────────────────
add_custom_command(
    OUTPUT ${CMAKE_BINARY_DIR}/omarchy-software-core
    COMMAND ${CARGO} build --release --locked
            --manifest-path ${CMAKE_SOURCE_DIR}/Cargo.toml
            --target-dir ${CMAKE_BINARY_DIR}/cargo
    COMMAND ${CMAKE_COMMAND} -E copy
            ${CMAKE_BINARY_DIR}/cargo/release/omarchy-software-core
            ${CMAKE_BINARY_DIR}/omarchy-software-core
    DEPENDS
        src/main.rs
        src/db.rs
        src/aur.rs
        src/transaction.rs
        src/theme.rs
        src/config.rs
        src/process.rs
        Cargo.toml Cargo.lock
)
add_custom_target(core ALL DEPENDS ${CMAKE_BINARY_DIR}/omarchy-software-core)

# ── GUI ─────────────────────────────────────────────────────────────────────
qt_add_executable(omarchy-software
    ui/main.cpp
    ui/bridge.cpp
    ui/bridge.h
)

set(SOFTWARE_QML
    ui/Main.qml
    ui/Theme.js
    ui/PackageList.qml
    ui/PackageCard.qml
    ui/PreviewPane.qml
    ui/ProgressPanel.qml
    ui/SearchBar.qml
    ui/SourceBadge.qml
    ui/ConfirmDialog.qml
    ui/ErrorBanner.qml
    ui/TabBar.qml
    ui/omarchy-logo.svg
)
qt_add_resources(omarchy-software qml PREFIX "/" FILES ${SOFTWARE_QML})

target_link_libraries(omarchy-software PRIVATE
    Qt6::Core Qt6::Gui Qt6::Quick Qt6::Qml Qt6::QuickControls2 Qt6::Network
)
add_dependencies(omarchy-software core)

include(GNUInstallDirs)
install(TARGETS omarchy-software RUNTIME DESTINATION ${CMAKE_INSTALL_BINDIR})
install(PROGRAMS ${CMAKE_BINARY_DIR}/omarchy-software-core
        DESTINATION lib/omarchy-software)
install(FILES packaging/io.github.tcballard.Software.desktop
        DESTINATION ${CMAKE_INSTALL_DATADIR}/applications)
install(FILES packaging/io.github.tcballard.Software.svg
        DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps)
install(FILES LICENSE DESTINATION ${CMAKE_INSTALL_DATADIR}/licenses/omarchy-software)
install(FILES packaging/bindings.lua.example
        DESTINATION ${CMAKE_INSTALL_DATADIR}/omarchy-software)

include(CTest)
if(BUILD_TESTING)
    find_package(Qt6 REQUIRED COMPONENTS Test)
    qt_add_executable(bridge-test tests/bridge_test.cpp
                      ui/bridge.cpp ui/bridge.h)
    target_include_directories(bridge-test PRIVATE ui)
    target_link_libraries(bridge-test PRIVATE
        Qt6::Core Qt6::Gui Qt6::Test)
    add_dependencies(bridge-test core)
    add_test(NAME bridge COMMAND bridge-test)
endif()
