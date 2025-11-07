cmake_minimum_required(VERSION 3.20)
project(libvisual_wallpaper VERSION 0.1.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECompilerSettings NO_POLICY_SCOPE)
include(KDECMakeSettings)
include(FeatureSummary)
# --- User prefix friendly plugin/qml dirs -----------------------------------
# On Debian/Ubuntu multi-arch layouts, KDE installs to lib/x86_64-linux-gnu.
# Plasma (and QML) in a user session might not automatically scan the multiarch
# subdir inside ~/.local without env vars. For a user-local build we force
# generic qt6 paths to guarantee discovery:
#   ~/.local/lib/qt6/plugins
#   ~/.local/lib/qt6/qml
# We only do this if the install prefix is inside the user's HOME.
if(CMAKE_INSTALL_PREFIX MATCHES "^/home/")
    set(KDE_INSTALL_PLUGINDIR "${CMAKE_INSTALL_PREFIX}/lib/qt6/plugins" CACHE PATH "User plugin dir (generic)" FORCE)
    # Prefer qt6/qml (Plasma 6) but also install a duplicate to multiarch later if it exists.
    set(KDE_INSTALL_QMLDIR "${CMAKE_INSTALL_PREFIX}/lib/qt6/qml" CACHE PATH "User QML dir (generic)" FORCE)
endif()

# Keep ALT paths (generic) for optional duplication if desired later.
set(ALT_QT_PLUGIN_DIR "${KDE_INSTALL_PLUGINDIR}")

# Detect multi-arch library architecture (e.g. x86_64-linux-gnu) if available for dual install.
if(CMAKE_LIBRARY_ARCHITECTURE)
    set(MULTIARCH_LIBDIR "${CMAKE_INSTALL_PREFIX}/lib/${CMAKE_LIBRARY_ARCHITECTURE}")
    set(MULTIARCH_QMLDIR "${MULTIARCH_LIBDIR}/qml")
    set(MULTIARCH_PLUGINDIR "${MULTIARCH_LIBDIR}/qt6/plugins")
endif()

find_package(Qt6 REQUIRED COMPONENTS Core Gui Qml Quick)
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    pkg_check_modules(PULSEAUDIO libpulse-simple libpulse)
    pkg_check_modules(FFTW3 REQUIRED fftw3)
endif()

find_package(KF6 REQUIRED COMPONENTS CoreAddons I18n Package Config)
find_package(Plasma REQUIRED) # Provides Plasma::Plasma target (no Wallpaper C++ API in Plasma6)

# Optional: LibVisual for future implementation
# find_package(PkgConfig REQUIRED)
# pkg_check_modules(LIBVISUAL REQUIRED libvisual-0.4)

set(libvisual_wallpaper_SRCS plugin.cpp backend.cpp)
# QML module for config dialog live audio probe
qt_add_qml_module(libvisual_probe
    URI LibVisualProbe
    VERSION 1.0
    CLASS_NAME LibVisualProbePlugin
    NO_PLUGIN_OPTIONAL
    SOURCES probe.cpp probe.h
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/LibVisualProbe
)

# QML module for wallpaper backend (main audio + spectrum provider)
qt_add_qml_module(libvisual_backend
    URI LibVisualBackend
    VERSION 1.0
    CLASS_NAME LibVisualBackendPlugin
    NO_PLUGIN_OPTIONAL
    SOURCES backend.cpp backend.h
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/LibVisualBackend
)

target_link_libraries(libvisual_probe PRIVATE Qt6::Core Qt6::Qml ${PULSEAUDIO_LIBRARIES})
target_include_directories(libvisual_probe PRIVATE ${PULSEAUDIO_INCLUDE_DIRS})

target_link_libraries(libvisual_backend PRIVATE Qt6::Core Qt6::Gui Qt6::Qml ${PULSEAUDIO_LIBRARIES} ${FFTW3_LIBRARIES})
target_include_directories(libvisual_backend PRIVATE ${PULSEAUDIO_INCLUDE_DIRS} ${FFTW3_INCLUDE_DIRS})

# Ensure QML modules get installed to resolved KDE_INSTALL_QMLDIR (already forced above for user prefix)
install(TARGETS libvisual_probe DESTINATION ${KDE_INSTALL_QMLDIR}/LibVisualProbe)
install(FILES qmldir DESTINATION ${KDE_INSTALL_QMLDIR}/LibVisualProbe)

install(TARGETS libvisual_backend DESTINATION ${KDE_INSTALL_QMLDIR}/LibVisualBackend)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/LibVisualBackend/qmldir DESTINATION ${KDE_INSTALL_QMLDIR}/LibVisualBackend)

# Duplicate QML modules into multi-arch qml dir if that exists (for environments that only scan it)
if(MULTIARCH_QMLDIR AND NOT MULTIARCH_QMLDIR STREQUAL KDE_INSTALL_QMLDIR)
    install(TARGETS libvisual_probe DESTINATION ${MULTIARCH_QMLDIR}/LibVisualProbe)
    install(FILES qmldir DESTINATION ${MULTIARCH_QMLDIR}/LibVisualProbe)
    install(TARGETS libvisual_backend DESTINATION ${MULTIARCH_QMLDIR}/LibVisualBackend)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/LibVisualBackend/qmldir DESTINATION ${MULTIARCH_QMLDIR}/LibVisualBackend)
endif()


# Use conventional Plasma wallpaper target naming so macro computes paths correctly
kcoreaddons_add_plugin(plasma_wallpaper_org.kde.libvisual
    SOURCES ${libvisual_wallpaper_SRCS}
    INSTALL_NAMESPACE "plasma/wallpapers"
)

# Install plugin JSON explicitly alongside the plugin .so so discovery does not
# rely solely on the embedded JSON (some lookup paths prefer on-disk metadata).
install(FILES plasma_wallpaper_org.kde.libvisual.json DESTINATION ${KDE_INSTALL_PLUGINDIR}/plasma/wallpapers)
if(MULTIARCH_PLUGINDIR AND NOT MULTIARCH_PLUGINDIR STREQUAL KDE_INSTALL_PLUGINDIR)
    install(FILES plasma_wallpaper_org.kde.libvisual.json DESTINATION ${MULTIARCH_PLUGINDIR}/plasma/wallpapers)
endif()

# Ensure build output directory exists to avoid linking to /plasma/...
set_target_properties(plasma_wallpaper_org.kde.libvisual PROPERTIES
    LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/plugins"
)

target_link_libraries(plasma_wallpaper_org.kde.libvisual
    Qt6::Core
    Qt6::Gui
    Qt6::Qml
    KF6::CoreAddons
    KF6::I18n
    Plasma::Plasma
    ${PULSEAUDIO_LIBRARIES}
    ${FFTW3_LIBRARIES}
)

target_include_directories(plasma_wallpaper_org.kde.libvisual PRIVATE
    ${PULSEAUDIO_INCLUDE_DIRS}
    ${FFTW3_INCLUDE_DIRS}
)

# target_include_directories(plasma_wallpaper_libvisual PRIVATE
#     ${LIBVISUAL_INCLUDE_DIRS}  # Pro budoucí LibVisual integraci
# )

# Install wallpaper package with correct directory structure (contents/*)
install(DIRECTORY contents/ DESTINATION ${KDE_INSTALL_DATADIR}/plasma/wallpapers/org.kde.libvisual/contents)

# Install metadata.json at package root
install(FILES metadata.json DESTINATION ${KDE_INSTALL_DATADIR}/plasma/wallpapers/org.kde.libvisual/)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)

# Duplicate plugin library into multi-arch plugin dir if different
if(MULTIARCH_PLUGINDIR AND NOT MULTIARCH_PLUGINDIR STREQUAL KDE_INSTALL_PLUGINDIR)
    install(TARGETS plasma_wallpaper_org.kde.libvisual DESTINATION ${MULTIARCH_PLUGINDIR}/plasma/wallpapers)
endif()