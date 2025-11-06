#!/bin/bash

# Build script for LibVisual Desktop Background

set -e

echo "=== LibVisual Desktop Background Build Script ==="

# Check if we're in the right directory
if [ ! -f "CMakeLists.txt" ]; then
    echo "Error: CMakeLists.txt not found. Please run this script from the project root."
    exit 1
fi

# Create build directory
BUILD_DIR="build"
if [ -d "$BUILD_DIR" ]; then
    echo "Build directory exists. Cleaning..."
    rm -rf "$BUILD_DIR"
fi

mkdir -p "$BUILD_DIR"
cd "$BUILD_DIR"

echo "=== Configuring with CMake ==="
cmake .. -DCMAKE_BUILD_TYPE=Release

echo "=== Building ==="
make -j"$(nproc)"

echo "=== Build completed successfully ==="
echo "Executable: $PWD/libvisual-bg"
echo ""
echo "To install system-wide, run:"
echo "  sudo make install"
echo ""
echo "To run the application:"
echo "  ./libvisual-bg"
echo "  or"
echo "  ./libvisual-bg --autostart"