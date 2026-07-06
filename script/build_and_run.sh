#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
APP_NAME="KeyClean"
BUNDLE_ID="dev.local.KeyClean"
MIN_SYSTEM_VERSION="14.0"

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
DIST_DIR="$ROOT_DIR/dist"
APP_BUNDLE="$DIST_DIR/KeyClean.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_MACOS="$APP_CONTENTS/MacOS"
APP_RESOURCES="$APP_CONTENTS/Resources"
APP_BINARY="$APP_MACOS/$APP_NAME"
INFO_PLIST="$APP_CONTENTS/Info.plist"
APP_ICON="$ROOT_DIR/Sources/KeyClean/Resources/AppIcon.icns"
SIGN_IDENTITY="${CODESIGN_IDENTITY:-}"

if [[ -z "$SIGN_IDENTITY" ]]; then
  SIGN_IDENTITY="$(security find-identity -v -p codesigning 2>/dev/null | awk -F\" '/Apple Development/ { print $2; exit }')"
fi
if [[ -z "$SIGN_IDENTITY" ]]; then
  echo "No Apple Development signing identity found." >&2
  echo "Set CODESIGN_IDENTITY to a stable signing identity, or set CODESIGN_IDENTITY=- explicitly for ad-hoc development builds." >&2
  exit 1
fi

REMOTE_LATEST_TAG="$(git ls-remote --tags --refs origin 'v*' 2>/dev/null | awk '{ sub("refs/tags/", "", $2); print $2 }' | sort -Vr | head -1 || true)"
LOCAL_LATEST_TAG="$(git tag -l 'v*' --sort=-v:refname | head -1)"
LATEST_TAG="${REMOTE_LATEST_TAG:-$LOCAL_LATEST_TAG}"
DEFAULT_APP_VERSION="${LATEST_TAG#v}"
if [[ -z "$LATEST_TAG" || "$DEFAULT_APP_VERSION" == "$LATEST_TAG" ]]; then
  DEFAULT_APP_VERSION="0.1.0"
fi
DEFAULT_BUILD_NUMBER="$(echo "$DEFAULT_APP_VERSION" | awk -F. '{print $3}')"
if [[ -z "$DEFAULT_BUILD_NUMBER" || "$DEFAULT_BUILD_NUMBER" == "0" ]]; then
  DEFAULT_BUILD_NUMBER="1"
fi
APP_VERSION="${APP_VERSION:-$DEFAULT_APP_VERSION}"
APP_BUILD_NUMBER="${APP_BUILD_NUMBER:-${DEFAULT_BUILD_NUMBER:-1}}"

if [[ -d "$APP_BUNDLE" ]]; then
  while IFS= read -r pid; do
    [[ -z "$pid" ]] && continue
    process_args="$(ps -p "$pid" -o args= 2>/dev/null || true)"
    if [[ "$process_args" == "$APP_BINARY"* ]]; then
      kill "$pid" >/dev/null 2>&1 || true
    fi
  done < <(pgrep -x "$APP_NAME" 2>/dev/null || true)
fi

cd "$ROOT_DIR"
swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_MACOS" "$APP_RESOURCES"
cp "$BUILD_BINARY" "$APP_BINARY"
chmod +x "$APP_BINARY"
if [[ -f "$APP_ICON" ]]; then
  cp "$APP_ICON" "$APP_RESOURCES/AppIcon.icns"
fi

cat >"$INFO_PLIST" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
  <key>CFBundleExecutable</key>
  <string>$APP_NAME</string>
  <key>CFBundleIdentifier</key>
  <string>$BUNDLE_ID</string>
  <key>CFBundleName</key>
  <string>KeyClean</string>
  <key>CFBundleDisplayName</key>
  <string>KeyClean</string>
  <key>CFBundleIconFile</key>
  <string>AppIcon</string>
  <key>CFBundleIconName</key>
  <string>AppIcon</string>
  <key>CFBundlePackageType</key>
  <string>APPL</string>
  <key>CFBundleShortVersionString</key>
  <string>$APP_VERSION</string>
  <key>CFBundleVersion</key>
  <string>$APP_BUILD_NUMBER</string>
  <key>LSApplicationCategoryType</key>
  <string>public.app-category.utilities</string>
  <key>LSMinimumSystemVersion</key>
  <string>$MIN_SYSTEM_VERSION</string>
  <key>LSUIElement</key>
  <true/>
  <key>NSHighResolutionCapable</key>
  <true/>
  <key>NSPrincipalClass</key>
  <string>NSApplication</string>
</dict>
</plist>
PLIST

/usr/bin/codesign --force --deep --sign "$SIGN_IDENTITY" "$APP_BUNDLE" >/dev/null

open_app() {
  /usr/bin/open -n "$APP_BUNDLE"
}

case "$MODE" in
  run)
    open_app
    ;;
  --debug|debug)
    lldb -- "$APP_BINARY"
    ;;
  --logs|logs)
    open_app
    /usr/bin/log stream --info --style compact --predicate "process == \"$APP_NAME\""
    ;;
  --telemetry|telemetry)
    open_app
    /usr/bin/log stream --info --style compact --predicate "subsystem == \"$BUNDLE_ID\""
    ;;
  --verify|verify)
    open_app
    sleep 1
    pgrep -x "$APP_NAME" >/dev/null
    ;;
  *)
    echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2
    exit 2
    ;;
esac
