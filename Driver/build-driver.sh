#!/bin/zsh
set -euo pipefail

SOURCE_DRIVER="${1:-/Library/Audio/Plug-Ins/HAL/BlackHole2ch.driver}"
SCRIPT_DIR="${0:A:h}"
BUILD_DIR="$SCRIPT_DIR/build"
OUTPUT_DRIVER="$BUILD_DIR/vRemoteDriver.driver"
EXECUTABLE="$OUTPUT_DRIVER/Contents/MacOS/BlackHole"
PLIST="$OUTPUT_DRIVER/Contents/Info.plist"

if [[ ! -d "$SOURCE_DRIVER" ]]; then
  print -u2 "Missing source driver: $SOURCE_DRIVER"
  exit 1
fi

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
ditto "$SOURCE_DRIVER" "$OUTPUT_DRIVER"
rm -rf "$OUTPUT_DRIVER/Contents/_CodeSignature"

# Keep every binary replacement exactly the same byte length. This lets the
# proof of concept reuse the installed universal BlackHole binary without Xcode.
perl -0777 -pi -e '
  s/audio\.existential\.BlackHole2ch/audio.local.vRemoteDriver2chXX/g;
  s/BlackHole%ich_2_UID/vRemoteDr%ich_2_UID/g;
  s/BlackHole%ich_ModelUID/vRemoteDr%ich_ModelUID/g;
  s/BlackHole%ich_UID/vRemoteDr%ich_UID/g;
  s/BlackHole%ich 2/vRemoteDr%ich 2/g;
  s/BlackHole%ich/vRemoteDr%ich/g;
  s/BlackHole %ich 2/vRemoteDr %ich 2/g;
  s/BlackHole %ich/vRemoteDr %ich/g;
  s/triv/ bsu/g;
' "$EXECUTABLE"

/usr/libexec/PlistBuddy -c "Set :CFBundleIdentifier audio.local.vRemoteDriver2chXX" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFBundleName vRemote Driver" "$PLIST"

# The factory UUID differs between upstream BlackHole releases, so rewrite the
# whole mapping instead of assuming a specific value.
FACTORY="B7C4C615-9E72-4C83-A329-71C4E50E4A91"
/usr/libexec/PlistBuddy -c "Delete :CFPlugInFactories" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFPlugInFactories dict" "$PLIST"
/usr/libexec/PlistBuddy -c "Add :CFPlugInFactories:$FACTORY string BlackHole_Create" "$PLIST"
/usr/libexec/PlistBuddy -c "Set :CFPlugInTypes:443ABAB8-E7B3-491A-B985-BEB9187030DB:0 $FACTORY" "$PLIST"

codesign --force --deep --sign - --timestamp=none "$OUTPUT_DRIVER"

print "Built: $OUTPUT_DRIVER"
print "Bundle ID: $(defaults read "$PLIST" CFBundleIdentifier)"
print "Architectures: $(lipo -archs "$EXECUTABLE")"
codesign --verify --deep --strict --verbose=2 "$OUTPUT_DRIVER"
