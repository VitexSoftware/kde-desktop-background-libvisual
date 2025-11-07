cmake_minimum_required(VERSION 3.16)

project(plasma-audiovisualizer-wallpaper)

# Find required packages
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 REQUIRED COMPONENTS
    Core
    Quick
    Qml
)

find_package(KF6 REQUIRED COMPONENTS
    Package
    I18n
)

find_package(Plasma REQUIRED)

# Find FFTW3
find_package(PkgConfig REQUIRED)
pkg_check_modules(FFTW3 REQUIRED fftw3)

# Find PulseAudio
pkg_check_modules(PULSEAUDIO REQUIRED libpulse libpulse-simple)

# Set C++ standard
set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Plugin sources
set(audiovisualizer_SRCS
    src/audiovisualizerbackend.cpp
    src/plugin.cpp
)

# Create the plugin library
add_library(plasma_wallpaper_audiovisualizer SHARED ${audiovisualizer_SRCS})

target_link_libraries(plasma_wallpaper_audiovisualizer
    Qt6::Core
    Qt6::Quick
    Qt6::Qml
    KF6::Package
    KF6::I18n
    ${FFTW3_LIBRARIES}
    ${PULSEAUDIO_LIBRARIES}
)

target_include_directories(plasma_wallpaper_audiovisualizer PRIVATE
    ${FFTW3_INCLUDE_DIRS}
    ${PULSEAUDIO_INCLUDE_DIRS}
)

target_compile_definitions(plasma_wallpaper_audiovisualizer PRIVATE
    ${FFTW3_CFLAGS_OTHER}
    ${PULSEAUDIO_CFLAGS_OTHER}
)

# Install the plugin
install(TARGETS plasma_wallpaper_audiovisualizer DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/audiovisualizer)

# Install QML module files
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/qmldir.in ${CMAKE_CURRENT_BINARY_DIR}/qmldir @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/qmldir DESTINATION ${KDE_INSTALL_QMLDIR}/org/kde/plasma/audiovisualizer)

# Install wallpaper package
kpackage_install_package(contents org.kde.plasma.audiovisualizer wallpapers)
install(FILES metadata.json DESTINATION ${KDE_INSTALL_DATADIR}/plasma/wallpapers/org.kde.plasma.audiovisualizer)

# Install desktop file for System Settings
configure_file(${CMAKE_CURRENT_SOURCE_DIR}/plasma-wallpaper-audiovisualizer.desktop.in
               ${CMAKE_CURRENT_BINARY_DIR}/plasma-wallpaper-audiovisualizer.desktop @ONLY)
install(FILES ${CMAKE_CURRENT_BINARY_DIR}/plasma-wallpaper-audiovisualizer.desktop
        DESTINATION ${KDE_INSTALL_DATADIR}/kservices5/plasma-wallpapers)

# Translation support
ki18n_install(po)