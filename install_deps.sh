#!/bin/bash

# Install dependencies for LibVisual Desktop Background

set -e

echo "=== Installing Dependencies for LibVisual Desktop Background ==="

# Detect distribution
if [ -f /etc/debian_version ]; then
    # Debian/Ubuntu
    echo "Detected Debian/Ubuntu system"
    sudo apt update
    sudo apt install -y \
        build-essential \
        cmake \
        pkg-config \
        qt6-base-dev \
        qt6-tools-dev \
        libvisual-0.4-dev \
        libpulse-dev \
        libx11-dev \
        libxrender-dev \
        libvisual-0.4-plugins

elif [ -f /etc/redhat-release ]; then
    # Fedora/CentOS/RHEL
    echo "Detected Red Hat based system"
    sudo dnf install -y \
        gcc-c++ \
        cmake \
        pkgconfig \
        qt6-qtbase-devel \
        qt6-qttools-devel \
        libvisual-devel \
        pulseaudio-libs-devel \
        libX11-devel \
        libXrender-devel \
        libvisual-plugins

elif [ -f /etc/arch-release ]; then
    # Arch Linux
    echo "Detected Arch Linux system"
    sudo pacman -S --needed \
        base-devel \
        cmake \
        pkgconf \
        qt6-base \
        qt6-tools \
        libvisual \
        pulseaudio \
        libx11 \
        libxrender \
        libvisual-plugins

elif [ -f /etc/gentoo-release ]; then
    # Gentoo
    echo "Detected Gentoo system"
    sudo emerge -av \
        dev-util/cmake \
        dev-qt/qtcore:6 \
        dev-qt/qtgui:6 \
        dev-qt/qtwidgets:6 \
        media-libs/libvisual \
        media-sound/pulseaudio \
        x11-libs/libX11 \
        x11-libs/libXrender

else
    echo "Unsupported distribution. Please install dependencies manually:"
    echo "- cmake"
    echo "- Qt6 (Core, GUI, Widgets)"
    echo "- libvisual-0.4"
    echo "- PulseAudio development libraries"
    echo "- X11 development libraries"
    echo "- libvisual plugins"
    exit 1
fi

echo "=== Dependencies installed successfully ==="
echo "You can now run ./build.sh to compile the application."