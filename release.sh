#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
PLIST="$SCRIPT_DIR/Packaging/Info.plist"
VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$PLIST")
TAG="v$VERSION"
PKG="$SCRIPT_DIR/dist/RemoteMic-$VERSION.pkg"
DMG="$SCRIPT_DIR/dist/RemoteMic-$VERSION.dmg"
NOTES="${1:-}"

cd "$SCRIPT_DIR"
"$SCRIPT_DIR/run-self-tests.sh"
"$SCRIPT_DIR/build-pkg.sh"
"$SCRIPT_DIR/build-dmg.sh"

# 内置更新只认 Release 附件里的 .pkg / .dmg，因此两者都要随 Release 上传。
if gh release view "$TAG" >/dev/null 2>&1; then
  gh release upload "$TAG" "$PKG" "$DMG" --clobber
else
  if [[ -n "$NOTES" ]]; then
    gh release create "$TAG" "$PKG" "$DMG" \
      --title "RemoteMic $VERSION" --notes-file "$NOTES"
  else
    gh release create "$TAG" "$PKG" "$DMG" \
      --title "RemoteMic $VERSION" --generate-notes
  fi
fi

print "Released $TAG"
print "  $PKG"
print "  $DMG"
