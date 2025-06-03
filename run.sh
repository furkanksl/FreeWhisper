#!/bin/bash

# Set the scheme name and configuration
SCHEME="FreeWhisper"
CONFIGURATION="Debug"

# Set build directory relative to script location
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BUILD_DIR="$SCRIPT_DIR/Build"

# Clean up previous builds
echo "Cleaning up previous builds..."
rm -rf "$BUILD_DIR"

# First, resolve package dependencies
echo "Resolving Swift Package Manager dependencies..."
xcodebuild -resolvePackageDependencies -scheme "$SCHEME" -quiet

if [ $? -ne 0 ]; then
    echo "Failed to resolve package dependencies"
    exit 1
fi

echo "Package dependencies resolved successfully!"

# Build the project with simplified parameters
echo "Building FreeWhisper..."
BUILD_OUTPUT=$(xcodebuild -scheme "$SCHEME" -configuration "$CONFIGURATION" -destination 'platform=macOS,arch=arm64' -derivedDataPath ./Build build 2>&1)

if [ $? -ne 0 ]; then
    echo "Build failed:"
    echo "$BUILD_OUTPUT"
    exit 1
fi

echo "Build succeeded!"

# Find the built app
APP_PATH=$(find ./Build -name "FreeWhisper.app" -type d | head -1)

if [ -z "$APP_PATH" ]; then
    echo "Error: FreeWhisper.app not found in build directory"
    echo "Looking for app in build directory..."
    find ./Build -name "*.app" -type d
    exit 1
fi 

echo "Found app at: $APP_PATH"
echo "Removing extended attributes..."
xattr -d com.apple.quarantine "$APP_PATH" 2>/dev/null || true

echo "Launching FreeWhisper..."
"$APP_PATH/Contents/MacOS/FreeWhisper" 