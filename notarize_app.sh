## example usage:
## ./notarize_app.sh "Developer ID Application: Furkan Koseoglu (Q2MA37YP23)"

#!/bin/bash
set -e

# === Configuration Variables ===
APP_NAME="FreeWhisper"                                   
APP_PATH="./build/Build/Products/Release/FreeWhisper.app"                        
ZIP_PATH="./build/FreeWhisper.zip"                        
BUNDLE_ID="com.furkanksl.FreeWhisper"                      # ✅ Your bundle ID
KEYCHAIN_PROFILE="FreeWhisper-Notarization"               # ✅ You'll create this profile
CODE_SIGN_IDENTITY="${1}"
DEVELOPMENT_TEAM="Q2MA37YP23"                              # ✅ Your Apple Developer Team ID

# Clean libwhisper build directory with proper permissions handling
if [ -d "libwhisper/build" ]; then
    echo "Cleaning libwhisper/build directory..."
    chmod -R 755 libwhisper/build 2>/dev/null || true
    rm -rf libwhisper/build 2>/dev/null || {
        echo "Normal removal failed, trying with sudo..."
        sudo rm -rf libwhisper/build
    }
fi

cmake -G Xcode -B libwhisper/build -S libwhisper

# Clean build directory with proper permissions handling
if [ -d "build" ]; then
    echo "Cleaning build directory..."
    chmod -R 755 build 2>/dev/null || true
    rm -rf build 2>/dev/null || {
        echo "Normal removal failed, trying with sudo..."
        sudo rm -rf build
    }
fi

xcodebuild \
  -scheme "FreeWhisper" \
  -configuration Release \
  -destination "platform=macOS,arch=arm64" \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM="${DEVELOPMENT_TEAM}" \
  CODE_SIGN_IDENTITY="${CODE_SIGN_IDENTITY}" \
  OTHER_CODE_SIGN_FLAGS=--timestamp \
  CODE_SIGN_INJECT_BASE_ENTITLEMENTS=NO \
  -derivedDataPath build \
  build

rm -f "${ZIP_PATH}"

current_dir=$(pwd)
cd $(dirname "${APP_PATH}") && zip -r -y "${current_dir}/${ZIP_PATH}" $(basename "${APP_PATH}")
cd "${current_dir}"

xcrun notarytool submit "${ZIP_PATH}" --wait --keychain-profile "${KEYCHAIN_PROFILE}"

xcrun stapler staple "${APP_PATH}"

# Create DMG with Applications folder shortcut
echo "Creating DMG..."

# Clean up any existing DMG and ensure no volumes are mounted
rm -f "${APP_NAME}.dmg" 2>/dev/null || true
rm -f "${APP_NAME}_temp.sparseimage" 2>/dev/null || true

# Unmount any existing FreeWhisper volumes
hdiutil detach "/Volumes/${APP_NAME}" 2>/dev/null || true
hdiutil detach "/Volumes/FreeWhisper" 2>/dev/null || true

# Create a temporary directory and add Applications folder shortcut
echo "Creating DMG with Applications folder shortcut..."
TEMP_DIR="dmg_temp_$$"
mkdir -p "$TEMP_DIR"
cp -R "${APP_PATH}" "$TEMP_DIR/"

# Create Applications folder shortcut
ln -s /Applications "$TEMP_DIR/Applications"

# Create DMG directly from temp directory without mounting
hdiutil makehybrid -hfs -hfs-volume-name "${APP_NAME}" -o "${APP_NAME}_temp.dmg" "$TEMP_DIR"

# Convert to compressed DMG
hdiutil convert "${APP_NAME}_temp.dmg" -format UDZO -o "${APP_NAME}.dmg"

# Clean up temp files
rm -rf "$TEMP_DIR"
rm -f "${APP_NAME}_temp.dmg"

echo "Signing and notarizing DMG..."
codesign --sign "${CODE_SIGN_IDENTITY}" "${APP_NAME}.dmg"

xcrun notarytool submit "${APP_NAME}.dmg" --wait --keychain-profile "${KEYCHAIN_PROFILE}"
xcrun stapler staple "${APP_NAME}.dmg"

echo "Successfully notarized ${APP_NAME}"
