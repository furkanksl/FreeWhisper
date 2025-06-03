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

rm -rf libwhisper/build
cmake -G Xcode -B libwhisper/build -S libwhisper

rm -rf build

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

# Create DMG with Applications folder alias for proper installer experience
rm -f "${APP_NAME}.dmg"
DMG_TEMP_DIR="dmg_temp"
rm -rf "${DMG_TEMP_DIR}"
mkdir "${DMG_TEMP_DIR}"

# Copy the app to temp directory
cp -R "${APP_PATH}" "${DMG_TEMP_DIR}/"

# Create Applications folder alias
ln -s /Applications "${DMG_TEMP_DIR}/Applications"

# Create DMG from temp directory
hdiutil create -volname "${APP_NAME}" -srcfolder "${DMG_TEMP_DIR}" -ov -format UDZO "${APP_NAME}.dmg"

# Clean up temp directory
rm -rf "${DMG_TEMP_DIR}"

codesign --sign "${CODE_SIGN_IDENTITY}" "${APP_NAME}.dmg"
xcrun notarytool submit "${APP_NAME}.dmg" --wait --keychain-profile "${KEYCHAIN_PROFILE}"
xcrun stapler staple "${APP_NAME}.dmg"  

echo "Successfully notarized ${APP_NAME}"
