cmake_minimum_required(VERSION 3.16)
project(libvisual-bg VERSION 1.0.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Qt6 REQUIRED COMPONENTS Core Widgets DBus)
find_package(PkgConfig REQUIRED)

# Enable Qt6 features
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find libvisual
pkg_check_modules(LIBVISUAL REQUIRED libvisual-0.4)

# Find X11 libraries
find_package(X11 REQUIRED)

# Find PulseAudio
pkg_check_modules(PULSEAUDIO REQUIRED libpulse-simple libpulse)

# Include directories
include_directories(${LIBVISUAL_INCLUDE_DIRS})
include_directories(${PULSEAUDIO_INCLUDE_DIRS})
include_directories(${X11_INCLUDE_DIR})

# Source files
set(SOURCES
    src/main.cpp
    src/visualizer.cpp
    src/settings.cpp
    src/audio_input.cpp
    src/desktop_renderer.cpp
    src/gui.cpp
)

set(HEADERS
    src/visualizer.h
    src/settings.h
    src/audio_input.h
    src/desktop_renderer.h
    src/gui.h
)

# Create executable
add_executable(libvisual-bg ${SOURCES} ${HEADERS})

# Link libraries
target_link_libraries(libvisual-bg
    Qt6::Core
    Qt6::Widgets
    Qt6::DBus
    ${LIBVISUAL_LIBRARIES}
    ${X11_LIBRARIES}
    ${PULSEAUDIO_LIBRARIES}
    pthread
)

# Compiler flags
target_compile_options(libvisual-bg PRIVATE
    ${LIBVISUAL_CFLAGS_OTHER}
    ${PULSEAUDIO_CFLAGS_OTHER}
)

# Install target
install(TARGETS libvisual-bg DESTINATION bin)