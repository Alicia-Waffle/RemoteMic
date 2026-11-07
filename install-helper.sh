#!/bin/zsh
set -euo pipefail

SCRIPT_DIR="${0:A:h}"
LABEL="local.simaqingfeng.vRemote.hidhelper"
HELPER_SOURCE="$SCRIPT_DIR/dist/build/vRemote.app/Contents/Helpers/vRemoteHIDHelper"
HELPER_DEST="/Library/PrivilegedHelperTools/$LABEL"
PLIST_DEST="/Library/LaunchDaemons/$LABEL.plist"

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

if [[ ! -x "$HELPER_SOURCE" ]]; then
  print -u2 "Helper not built. Run ./package-app.sh first."
  exit 1
fi

# A root daemon is a small, local privilege boundary: the app itself stays
# sandbox-free but unprivileged, and only this tool touches the HID
# collection. macOS refuses kIOHIDOptionsTypeSeizeDevice for keyboard-class
# devices to anything that is not root.
install -o root -g wheel -m 755 "$HELPER_SOURCE" "$HELPER_DEST"
codesign --force --sign - --timestamp=none "$HELPER_DEST"

cat > "$PLIST_DEST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>Label</key>
  <string>${LABEL}</string>
  <key>ProgramArguments</key>
  <array>
    <string>${HELPER_DEST}</string>
  </array>
  <key>MachServices</key>
  <dict>
    <key>${LABEL}</key>
    <true/>
  </dict>
  <key>RunAtLoad</key>
  <true/>
  <key>KeepAlive</key>
  <false/>
  <key>ProcessType</key>
  <string>Interactive</string>
</dict>
</plist>
PLIST
chown root:wheel "$PLIST_DEST"
chmod 644 "$PLIST_DEST"

launchctl bootout system "$PLIST_DEST" 2>/dev/null || true
launchctl bootstrap system "$PLIST_DEST"

print "Installed: $HELPER_DEST"
print "LaunchDaemon: $PLIST_DEST"
if launchctl print "system/$LABEL" >/dev/null 2>&1; then
  print "Status: running (system/$LABEL)"
else
  print -u2 "Status: not running; check 'log show --predicate \"process == \\\"vRemoteHIDHelper\\\"\" --last 1m'"
  exit 1
fi
