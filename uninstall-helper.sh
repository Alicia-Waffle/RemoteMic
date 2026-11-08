#!/bin/zsh
set -euo pipefail

LABEL="local.simaqingfeng.RemoteMic.hidhelper"
LEGACY_LABEL="local.simaqingfeng.vRemote.hidhelper"
HELPER_DEST="/Library/PrivilegedHelperTools/$LABEL"
PLIST_DEST="/Library/LaunchDaemons/$LABEL.plist"

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
rm -f "$PLIST_DEST" "$HELPER_DEST"

launchctl bootout system "/Library/LaunchDaemons/$LEGACY_LABEL.plist" 2>/dev/null || true
rm -f "/Library/LaunchDaemons/$LEGACY_LABEL.plist" \
  "/Library/PrivilegedHelperTools/$LEGACY_LABEL"

print "Removed: $HELPER_DEST"
print "Removed: $PLIST_DEST"
