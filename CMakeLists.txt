cmake_minimum_required(VERSION 3.16)
project(libvisual-bg VERSION 1.2.0)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# Find required packages
find_package(Qt6 REQUIRED COMPONENTS Core Widgets DBus OpenGL)
find_package(PkgConfig REQUIRED)

# Enable Qt6 features
set(CMAKE_AUTOMOC ON)
set(CMAKE_AUTORCC ON)
set(CMAKE_AUTOUIC ON)

# Find libvisual
pkg_check_modules(LIBVISUAL REQUIRED libvisual-0.4)

# Find X11 libraries
find_package(X11 REQUIRED)

# Find OpenGL + GLX (required for hardware-accelerated desktop rendering)
find_package(OpenGL REQUIRED COMPONENTS OpenGL)

# Find PulseAudio
pkg_check_modules(PULSEAUDIO REQUIRED libpulse-simple libpulse)

# Find projectM (optional)
pkg_check_modules(PROJECTM libprojectM)
if(PROJECTM_FOUND)
    message(STATUS "ProjectM found - enabling projectM support")
    add_definitions(-DHAVE_PROJECTM)
else()
    message(STATUS "ProjectM not found - building without projectM support")
endif()

# Include directories
include_directories(${LIBVISUAL_INCLUDE_DIRS})
include_directories(${PULSEAUDIO_INCLUDE_DIRS})
include_directories(${X11_INCLUDE_DIR})
if(PROJECTM_FOUND)
    include_directories(${PROJECTM_INCLUDE_DIRS})
endif()

# Source files
set(SOURCES
    src/main.cpp
    src/visualizer.cpp
    src/settings.cpp
    src/audio_input.cpp
    src/desktop_renderer.cpp
    src/gui.cpp
    src/visualization_factory.cpp
)

set(HEADERS
    src/visualizer.h
    src/settings.h
    src/audio_input.h
    src/desktop_renderer.h
    src/gui.h
    src/visualization_engine.h
    src/visualization_factory.h
)

# Add projectM sources if available
if(PROJECTM_FOUND)
    list(APPEND SOURCES src/projectm_visualizer.cpp)
    list(APPEND HEADERS src/projectm_visualizer.h)
endif()

# Create executable
add_executable(libvisual-bg ${SOURCES} ${HEADERS})

# Link libraries
target_link_libraries(libvisual-bg
    Qt6::Core
    Qt6::Widgets
    Qt6::DBus
    Qt6::OpenGL
    ${LIBVISUAL_LIBRARIES}
    ${X11_LIBRARIES}
    ${PULSEAUDIO_LIBRARIES}
    OpenGL::GL
    ${OPENGL_LIBRARIES}
    pthread
)

# Add projectM libraries if available
if(PROJECTM_FOUND)
    target_link_libraries(libvisual-bg ${PROJECTM_LIBRARIES})
endif()

# Compiler flags
target_compile_options(libvisual-bg PRIVATE
    ${LIBVISUAL_CFLAGS_OTHER}
    ${PULSEAUDIO_CFLAGS_OTHER}
)

# Install target
install(TARGETS libvisual-bg DESTINATION bin)

# Add wallpaper plugin subdirectory
add_subdirectory(plasma-wallpapers/org.kde.libvisual)