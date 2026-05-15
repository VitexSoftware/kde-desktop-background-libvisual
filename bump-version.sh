#!/bin/bash
# Automatic version bump script for kde-desktop-background-libvisual
# Increments the subminor version (e.g., 1.1.1 -> 1.1.2)

set -e

# Get current version from CMakeLists.txt
CURRENT_VERSION=$(grep "^project(libvisual-bg VERSION" CMakeLists.txt | sed 's/.*VERSION \([0-9.]*\)).*/\1/')

if [ -z "$CURRENT_VERSION" ]; then
    echo "Error: Could not find version in CMakeLists.txt"
    exit 1
fi

echo "Current version: $CURRENT_VERSION"

# Parse version components
MAJOR=$(echo $CURRENT_VERSION | cut -d. -f1)
MINOR=$(echo $CURRENT_VERSION | cut -d. -f2)
PATCH=$(echo $CURRENT_VERSION | cut -d. -f3)

# Increment patch version
NEW_PATCH=$((PATCH + 1))
NEW_VERSION="${MAJOR}.${MINOR}.${NEW_PATCH}"

echo "New version: $NEW_VERSION"

# Update CMakeLists.txt
sed -i "s/project(libvisual-bg VERSION $CURRENT_VERSION)/project(libvisual-bg VERSION $NEW_VERSION)/" CMakeLists.txt

# Update metadata.json
sed -i "s/\"Version\": \"$CURRENT_VERSION\"/\"Version\": \"$NEW_VERSION\"/" plasma-wallpapers/org.kde.libvisual/metadata.json

# Update config.qml (handle i18n format)
sed -i "s/Version $CURRENT_VERSION - VitexSoftware/Version $NEW_VERSION - VitexSoftware/" plasma-wallpapers/org.kde.libvisual/contents/ui/config.qml

# Update debian/changelog
DATE=$(date -R)
CHANGELOG_ENTRY="kde-desktop-background-libvisual ($NEW_VERSION-1) unstable; urgency=medium

  * Version bump to $NEW_VERSION

 -- Vítězslav Dvořák <info@vitexsoftware.cz>  $DATE

"

# Prepend to changelog
echo "$CHANGELOG_ENTRY$(cat debian/changelog)" > debian/changelog

echo "Version bumped to $NEW_VERSION"
echo "Files updated:"
echo "  - CMakeLists.txt"
echo "  - plasma-wallpapers/org.kde.libvisual/metadata.json"
echo "  - plasma-wallpapers/org.kde.libvisual/contents/ui/config.qml"
echo "  - debian/changelog"
echo ""
echo "Please review changes and commit."
