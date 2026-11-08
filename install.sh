#!/bin/zsh
set -euo pipefail

# One-shot installer for RemoteMic: app + virtual audio driver + privileged HID
# helper. Run with sudo (the .command wrapper does that for you).

SCRIPT_DIR="${0:A:h}"
APP_SOURCE="$SCRIPT_DIR/RemoteMic.app"
if [[ ! -d "$APP_SOURCE" ]]; then
  APP_SOURCE="$SCRIPT_DIR/dist/build/RemoteMic.app"
fi
APP_DEST="/Applications/RemoteMic.app"

LABEL="local.simaqingfeng.RemoteMic.hidhelper"
HELPER_SOURCE="$APP_SOURCE/Contents/Helpers/RemoteMicHIDHelper"
HELPER_DEST="/Library/PrivilegedHelperTools/$LABEL"
PLIST_DEST="/Library/LaunchDaemons/$LABEL.plist"
DRIVER_SOURCE="$APP_SOURCE/Contents/Resources/Driver/RemoteMicDriver.driver"
DRIVER_DEST="/Library/Audio/Plug-Ins/HAL/RemoteMicDriver.driver"
HAL_DIR="/Library/Audio/Plug-Ins/HAL"

LEGACY_LABEL="local.simaqingfeng.vRemote.hidhelper"
LEGACY_DRIVER="/Library/Audio/Plug-Ins/HAL/vRemoteDriver.driver"

if [[ $EUID -ne 0 ]]; then
  exec sudo "$0" "$@"
fi

if [[ ! -d "$APP_SOURCE" ]]; then
  print -u2 "RemoteMic.app not found next to this script."
  exit 1
fi
if [[ ! -d "$DRIVER_SOURCE" ]]; then
  print -u2 "Bundled audio driver missing at $DRIVER_SOURCE"
  exit 1
fi

print "==> Installing app"
pkill -x RemoteMic 2>/dev/null || true
rm -rf "/Applications/vRemote.app" "$APP_DEST"
ditto "$APP_SOURCE" "$APP_DEST"
chown -R "$(stat -f %Su /dev/console):staff" "$APP_DEST"
xattr -dr com.apple.quarantine "$APP_DEST" 2>/dev/null || true

print "==> Installing audio driver"
rm -rf "$DRIVER_DEST" "$LEGACY_DRIVER"
mkdir -p "$HAL_DIR"
ditto "$DRIVER_SOURCE" "$DRIVER_DEST"
chown -R root:wheel "$DRIVER_DEST"
find "$DRIVER_DEST" -type d -exec chmod 755 {} \;
find "$DRIVER_DEST" -type f -exec chmod 644 {} \;
chmod 755 "$DRIVER_DEST/Contents/MacOS/BlackHole"
codesign --force --sign - --timestamp=none "$DRIVER_DEST" >/dev/null 2>&1

print "==> Installing HID helper"
launchctl bootout system "/Library/LaunchDaemons/$LEGACY_LABEL.plist" 2>/dev/null || true
rm -f "/Library/LaunchDaemons/$LEGACY_LABEL.plist" \
  "/Library/PrivilegedHelperTools/$LEGACY_LABEL"
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

print "==> Restarting Core Audio"
killall -9 coreaudiod 2>/dev/null || true
sleep 2

console_user=$(/usr/bin/stat -f '%Su' /dev/console)
if [[ -n "$console_user" && "$console_user" != "root" ]]; then
  console_uid=$(/usr/bin/id -u "$console_user")
  /bin/launchctl asuser "$console_uid" \
    /usr/bin/sudo -u "$console_user" \
    /usr/bin/open "$APP_DEST" >/dev/null 2>&1 || true
fi

print ""
print "Installed."
print "  App:      $APP_DEST"
print "  Driver:   $DRIVER_DEST  (device name: RemoteMic 2ch)"
print "  Helper:   $HELPER_DEST"
print ""
print "Next: grant Microphone and Input Monitoring permissions when macOS asks."
