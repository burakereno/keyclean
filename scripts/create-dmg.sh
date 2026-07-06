#!/usr/bin/env bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PATH="${1:-$ROOT_DIR/.build/KeyClean.app}"
OUTPUT_DMG="${2:-$ROOT_DIR/KeyClean.dmg}"
VOLUME_NAME="${VOLUME_NAME:-KeyClean}"
APP_BUNDLE_NAME="$(basename "$APP_PATH")"
WINDOW_WIDTH=760
WINDOW_HEIGHT=610
ICON_SIZE=128
APP_X=245
APP_Y=300
APPLICATIONS_X=515
APPLICATIONS_Y=300

if [[ ! -d "$APP_PATH" ]]; then
  echo "App bundle not found: $APP_PATH" >&2
  exit 1
fi

WORK_DIR="$(mktemp -d)"
STAGING_DIR="$WORK_DIR/staging"
BACKGROUND_DIR="$STAGING_DIR/.background"
BACKGROUND_PATH="$BACKGROUND_DIR/background.png"
RW_DMG="$WORK_DIR/$VOLUME_NAME.rw.dmg"
MOUNT_DIR="$WORK_DIR/mount"
BACKGROUND_SCRIPT="$WORK_DIR/make-dmg-background.swift"
MOUNTED=0

cleanup() {
  if [[ "$MOUNTED" == "1" ]]; then
    hdiutil detach "$MOUNT_DIR" -quiet -force >/dev/null 2>&1 || true
  fi
  rm -rf "$WORK_DIR"
}
trap cleanup EXIT

mkdir -p "$BACKGROUND_DIR" "$MOUNT_DIR"
cp -R "$APP_PATH" "$STAGING_DIR/"
ln -s /Applications "$STAGING_DIR/Applications"

cat > "$BACKGROUND_SCRIPT" <<'SWIFT'
import AppKit
import Foundation

let outputPath = CommandLine.arguments[1]
let width: CGFloat = 760
let height: CGFloat = 610

func color(_ red: CGFloat, _ green: CGFloat, _ blue: CGFloat, _ alpha: CGFloat = 1) -> NSColor {
    NSColor(calibratedRed: red / 255, green: green / 255, blue: blue / 255, alpha: alpha)
}

let image = NSImage(size: NSSize(width: width, height: height))
image.lockFocus()

color(247, 248, 246).setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: width, height: height)).fill()

color(205, 212, 207).setStroke()
let grid = NSBezierPath()
grid.lineWidth = 1
for x in [CGFloat(120), CGFloat(640)] {
    grid.move(to: NSPoint(x: x, y: 0))
    grid.line(to: NSPoint(x: x, y: height))
}
for y in [CGFloat(210), CGFloat(410)] {
    grid.move(to: NSPoint(x: 0, y: y))
    grid.line(to: NSPoint(x: width, y: y))
}
grid.stroke()

let paragraph = NSMutableParagraphStyle()
paragraph.alignment = .center

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 31, weight: .semibold),
    .foregroundColor: color(42, 45, 52),
    .paragraphStyle: paragraph
]
let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 31, weight: .semibold),
    .foregroundColor: color(101, 111, 124),
    .paragraphStyle: paragraph
]

"KeyClean, built for quick".draw(
    in: NSRect(x: 0, y: 474, width: width, height: 42),
    withAttributes: titleAttributes
)
"keyboard cleaning".draw(
    in: NSRect(x: 0, y: 435, width: width, height: 42),
    withAttributes: subtitleAttributes
)

let hintAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 15, weight: .medium),
    .foregroundColor: color(137, 124, 113),
    .paragraphStyle: paragraph
]
"Drag KeyClean to Applications".draw(
    in: NSRect(x: 0, y: 154, width: width, height: 24),
    withAttributes: hintAttributes
)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiff),
    let png = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Could not render DMG background\\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath), options: .atomic)
SWIFT

xcrun swift "$BACKGROUND_SCRIPT" "$BACKGROUND_PATH"

rm -f "$OUTPUT_DMG"
hdiutil create \
  -volname "$VOLUME_NAME" \
  -srcfolder "$STAGING_DIR" \
  -format UDRW \
  -fs HFS+ \
  -ov \
  "$RW_DMG" >/dev/null

hdiutil attach "$RW_DMG" \
  -readwrite \
  -noverify \
  -noautoopen \
  -mountpoint "$MOUNT_DIR" >/dev/null
MOUNTED=1

/usr/bin/SetFile -a V "$MOUNT_DIR/.background" >/dev/null 2>&1 || true
/usr/bin/SetFile -a V "$MOUNT_DIR/Applications" >/dev/null 2>&1 || true

osascript <<APPLESCRIPT
tell application "Finder"
  set dmgFolder to POSIX file "$MOUNT_DIR" as alias
  open dmgFolder
  delay 1
  set current view of container window of dmgFolder to icon view
  set toolbar visible of container window of dmgFolder to false
  set statusbar visible of container window of dmgFolder to false
  set bounds of container window of dmgFolder to {100, 100, 100 + $WINDOW_WIDTH, 100 + $WINDOW_HEIGHT}
  set theViewOptions to the icon view options of container window of dmgFolder
  set arrangement of theViewOptions to not arranged
  set icon size of theViewOptions to $ICON_SIZE
  set label position of theViewOptions to bottom
  set background picture of theViewOptions to file ".background:background.png" of dmgFolder
  set position of item "$APP_BUNDLE_NAME" of dmgFolder to {$APP_X, $APP_Y}
  set position of item "Applications" of dmgFolder to {$APPLICATIONS_X, $APPLICATIONS_Y}
  update dmgFolder without registering applications
  delay 1
  close container window of dmgFolder
end tell
APPLESCRIPT

sync
hdiutil detach "$MOUNT_DIR" -quiet -force >/dev/null
MOUNTED=0

hdiutil convert "$RW_DMG" \
  -format UDZO \
  -imagekey zlib-level=9 \
  -o "$OUTPUT_DMG" >/dev/null

echo "Created $OUTPUT_DMG"
