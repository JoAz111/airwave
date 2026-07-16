#!/usr/bin/env bash
set -euo pipefail

MODE="${1:-run}"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_NAME="Airwave"
APP_BUNDLE="$ROOT_DIR/dist/$APP_NAME.app"
APP_CONTENTS="$APP_BUNDLE/Contents"
APP_BINARY="$APP_CONTENTS/MacOS/$APP_NAME"

if [[ -d /Applications/Xcode-beta.app ]]; then
  export DEVELOPER_DIR=/Applications/Xcode-beta.app/Contents/Developer
fi

pkill -x "$APP_NAME" >/dev/null 2>&1 || true
swift build
BUILD_BINARY="$(swift build --show-bin-path)/$APP_NAME"

rm -rf "$APP_BUNDLE"
mkdir -p "$APP_CONTENTS/MacOS" "$APP_CONTENTS/Resources"
cp "$BUILD_BINARY" "$APP_BINARY"
cp "$ROOT_DIR/Packaging/Info.plist" "$APP_CONTENTS/Info.plist"
DEVELOPER_DIR="$DEVELOPER_DIR" xcrun actool "$ROOT_DIR/Packaging/Assets.xcassets" \
  --compile "$APP_CONTENTS/Resources" \
  --platform macosx \
  --minimum-deployment-target 26.0 \
  --app-icon AppIcon \
  --output-partial-info-plist "$ROOT_DIR/.build/Airwave-Assets.plist" \
  --warnings \
  --notices
cp "$ROOT_DIR/Packaging/MenuBarIcon.png" "$APP_CONTENTS/Resources/MenuBarIcon.png"
cp "$ROOT_DIR/Packaging/MenuBarIcon@2x.png" "$APP_CONTENTS/Resources/MenuBarIcon@2x.png"
cp "$ROOT_DIR/Packaging/ToolbarIcon.png" "$APP_CONTENTS/Resources/ToolbarIcon.png"
cp "$ROOT_DIR/Packaging/ToolbarIcon@2x.png" "$APP_CONTENTS/Resources/ToolbarIcon@2x.png"
chmod +x "$APP_BINARY"
codesign --force --sign - --entitlements "$ROOT_DIR/Packaging/Airwave.entitlements" "$APP_BUNDLE"

open_app() { /usr/bin/open -n "$APP_BUNDLE"; }

case "$MODE" in
  run) open_app ;;
  --debug|debug) lldb -- "$APP_BINARY" ;;
  --logs|logs) open_app; /usr/bin/log stream --info --style compact --predicate "process == '$APP_NAME'" ;;
  --telemetry|telemetry) open_app; /usr/bin/log stream --info --style compact --predicate "subsystem == 'com.joeyazizoff.Airwave'" ;;
  --verify|verify) open_app; sleep 2; pgrep -x "$APP_NAME" >/dev/null ;;
  *) echo "usage: $0 [run|--debug|--logs|--telemetry|--verify]" >&2; exit 2 ;;
esac
