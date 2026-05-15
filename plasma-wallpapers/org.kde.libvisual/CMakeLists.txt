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
find_package(Qt6 OPTIONAL_COMPONENTS ShaderTools)
find_package(PkgConfig QUIET)
if(PkgConfig_FOUND)
    # libpulse (async API): pa_context, pa_stream, pa_threaded_mainloop
    # libpulse-simple is no longer used (replaced by pa_stream callbacks)
    pkg_check_modules(PULSEAUDIO REQUIRED libpulse)
    pkg_check_modules(FFTW3 REQUIRED fftw3)
endif()

find_package(KF6 REQUIRED COMPONENTS CoreAddons I18n Package Config)
find_package(Plasma REQUIRED) # Provides Plasma::Plasma target (no Wallpaper C++ API in Plasma6)

# Optional: LibVisual for future implementation
# find_package(PkgConfig REQUIRED)
# pkg_check_modules(LIBVISUAL REQUIRED libvisual-0.4)

set(libvisual_wallpaper_SRCS plugin.cpp)

# Unified QML module for both wallpaper and config dialog
qt_add_qml_module(audiovisualizer_probe
    URI AudioVisualizer
    VERSION 1.0
    CLASS_NAME AudioVisualizerPlugin
    NO_PLUGIN_OPTIONAL
    SOURCES audiovisualizer.cpp audiovisualizer.h
    OUTPUT_DIRECTORY ${CMAKE_CURRENT_BINARY_DIR}/AudioVisualizer
)

target_link_libraries(audiovisualizer_probe PRIVATE ${PULSEAUDIO_LIBRARIES} ${FFTW3_LIBRARIES})
target_include_directories(audiovisualizer_probe PRIVATE ${PULSEAUDIO_INCLUDE_DIRS} ${FFTW3_INCLUDE_DIRS})

# Set up RPATH for the plugin to find system libraries
set_target_properties(audiovisualizer_probe PROPERTIES
    INSTALL_RPATH "${KDE_INSTALL_LIBDIR};${CMAKE_INSTALL_PREFIX}/${KDE_INSTALL_LIBDIR}"
)

# Install unified QML module and backing library
install(TARGETS audiovisualizer_probe DESTINATION ${KDE_INSTALL_LIBDIR})
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/AudioVisualizer/qmldir DESTINATION ${KDE_INSTALL_QMLDIR}/AudioVisualizer)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/AudioVisualizer/audiovisualizer_probeplugin.so DESTINATION ${KDE_INSTALL_QMLDIR}/AudioVisualizer)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/AudioVisualizer/audiovisualizer_probe.qmltypes DESTINATION ${KDE_INSTALL_QMLDIR}/AudioVisualizer)

# Duplicate QML module into multi-arch qml dir if that exists
if(MULTIARCH_QMLDIR AND NOT MULTIARCH_QMLDIR STREQUAL KDE_INSTALL_QMLDIR)
    install(TARGETS audiovisualizer_probe DESTINATION ${KDE_INSTALL_LIBDIR})
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/AudioVisualizer/qmldir DESTINATION ${MULTIARCH_QMLDIR}/AudioVisualizer)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/AudioVisualizer/audiovisualizer_probeplugin.so DESTINATION ${MULTIARCH_QMLDIR}/AudioVisualizer)
    install(FILES ${CMAKE_CURRENT_BINARY_DIR}/AudioVisualizer/audiovisualizer_probe.qmltypes DESTINATION ${MULTIARCH_QMLDIR}/AudioVisualizer)
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

# AppStream metainfo + hicolor stock icon
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../../debian/io.github.vitexsoftware.kde_desktop_background_libvisual.metainfo.xml
    DESTINATION ${CMAKE_INSTALL_DATADIR}/metainfo)
install(FILES ${CMAKE_CURRENT_SOURCE_DIR}/../../kde-desktop-background-libvisual.svg
    DESTINATION ${CMAKE_INSTALL_DATADIR}/icons/hicolor/scalable/apps
    RENAME io.github.vitexsoftware.kde_desktop_background_libvisual.svg)

feature_summary(WHAT ALL FATAL_ON_MISSING_REQUIRED_PACKAGES)

# --- Mandelbrot GPU shader ---------------------------------------------------
# Compile the GLSL 4.40 fragment shader to a Qt Shader Binary (.qsb) so that
# the QML ShaderEffect can run it on the GPU instead of the Canvas CPU fallback.
# Requires Qt6::ShaderTools (qsb tool); silently skipped when not available.
if(Qt6ShaderTools_FOUND)
    qt6_add_shaders(plasma_wallpaper_org.kde.libvisual "mandelbrot_shader"
        BATCHABLE
        PRECOMPILE
        OPTIMIZED
        PREFIX "/shaders"
        FILES "contents/shaders/mandelbrot.frag"
    )
    message(STATUS "Mandelbrot GPU shader will be compiled (Qt6::ShaderTools found)")
else()
    # Fallback: find the qsb binary manually and use add_custom_command
    find_program(QSB_TOOL qsb
        HINTS "${Qt6_DIR}/../../../bin"
              "${Qt6Core_DIR}/../../../bin"
        DOC "Qt Shader Baker (qsb) tool")

    if(QSB_TOOL)
        set(MANDELBROT_QSB "${CMAKE_CURRENT_BINARY_DIR}/mandelbrot.frag.qsb")
        add_custom_command(
            OUTPUT  "${MANDELBROT_QSB}"
            COMMAND "${QSB_TOOL}"
                    --glsl "100es,120,150"
                    --hlsl 50
                    --msl 12
                    -o "${MANDELBROT_QSB}"
                    "${CMAKE_CURRENT_SOURCE_DIR}/contents/shaders/mandelbrot.frag"
            DEPENDS "contents/shaders/mandelbrot.frag"
            COMMENT "Compiling Mandelbrot fragment shader to QSB"
            VERBATIM
        )
        # Mark the generated file so CMake knows it won't exist at configure time
        set_property(SOURCE "${MANDELBROT_QSB}" PROPERTY GENERATED TRUE)

        # Embed into the plugin binary under qrc:/shaders/ — same path as the
        # qt6_add_shaders route so the QML shader URL is identical in both cases.
        qt_add_resources(plasma_wallpaper_org.kde.libvisual "mandelbrot_shader_res"
            PREFIX "/shaders"
            BASE   "${CMAKE_CURRENT_BINARY_DIR}"
            FILES  "${MANDELBROT_QSB}"
        )
        # Ensure the QSB is compiled before it is packaged into the QRC
        add_custom_target(mandelbrot_qsb_target DEPENDS "${MANDELBROT_QSB}")
        add_dependencies(plasma_wallpaper_org.kde.libvisual mandelbrot_qsb_target)

        message(STATUS "Mandelbrot GPU shader will be compiled via qsb at ${QSB_TOOL}")
    else()
        message(WARNING "qsb tool not found — Mandelbrot ShaderEffect will render blank (Canvas path removed)")
    endif()
endif()

# Duplicate plugin library into multi-arch plugin dir if different
if(MULTIARCH_PLUGINDIR AND NOT MULTIARCH_PLUGINDIR STREQUAL KDE_INSTALL_PLUGINDIR)
    install(TARGETS plasma_wallpaper_org.kde.libvisual DESTINATION ${MULTIARCH_PLUGINDIR}/plasma/wallpapers)
endif()