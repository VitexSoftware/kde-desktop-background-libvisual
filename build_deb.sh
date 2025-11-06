#!/bin/bash

# Script for testing Debian package build

set -e

echo "=== Testing Debian Package Build ==="

# Check if we're in the right directory
if [ ! -f "debian/control" ]; then
    echo "Error: debian/control not found. Please run this script from the project root."
    exit 1
fi

# Check if build dependencies are available
echo "=== Checking build dependencies ==="
missing_deps=""

if ! dpkg -l | grep -q "debhelper"; then
    missing_deps="$missing_deps debhelper"
fi

if ! dpkg -l | grep -q "cmake"; then
    missing_deps="$missing_deps cmake"
fi

if ! dpkg -l | grep -q "pkg-config"; then
    missing_deps="$missing_deps pkg-config"
fi

if [ -n "$missing_deps" ]; then
    echo "Missing build dependencies: $missing_deps"
    echo "Install with: sudo apt install$missing_deps"
    exit 1
fi

echo "Build dependencies OK"

# Clean previous build
echo "=== Cleaning previous build ==="
if [ -d "debian/kde-desktop-background-libvisual" ]; then
    rm -rf debian/kde-desktop-background-libvisual
fi

if [ -d "debian/tmp" ]; then
    rm -rf debian/tmp
fi

# Test package build
echo "=== Testing package build ==="
debuild -us -uc -b

echo "=== Package build completed ==="
echo "Built packages:"
ls -la ../kde-desktop-background-libvisual*.deb 2>/dev/null || echo "No .deb files found in parent directory"

echo ""
echo "To install the package, run:"
echo "  sudo dpkg -i ../kde-desktop-background-libvisual_*.deb"
echo "  sudo apt install -f  # to fix dependencies if needed"