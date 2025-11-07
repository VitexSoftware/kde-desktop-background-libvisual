#!/bin/bash
# Quick debug suppression deployment script

echo "Building and installing debug-free wallpaper..."

# Build
cmake --build build

# Install
make install

echo "Debug suppression complete. Restart plasmashell to test."