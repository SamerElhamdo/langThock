#!/bin/bash
# Full clean rebuild + reinstall of LangThock on macOS.
#   ./scripts/reinstall_macos.sh                 # ad-hoc signature (Accessibility must be re-granted after each build)
#   TEAMID=ABCDE12345 ./scripts/reinstall_macos.sh   # stable signature with your Apple team (recommended)
# Soundpacks in ~/Library/Application Support/Thock/Soundpacks are never touched.
set -uo pipefail

BUNDLE_ID="dev.langthock.LangThock"
APP="/Applications/LangThock.app"
cd "$(dirname "$0")/.."

echo "==> 1/6 Quit running apps"
pkill -x LangThock 2>/dev/null || true
pkill -x Thock 2>/dev/null || true

echo "==> 2/6 Remove old app, preferences and Accessibility approval"
rm -rf "$APP"
tccutil reset Accessibility "$BUNDLE_ID" 2>/dev/null || true
tccutil reset Accessibility dev.kamillobinski.Thock 2>/dev/null || true
defaults delete "$BUNDLE_ID" 2>/dev/null || true
rm -f "$HOME/Library/Preferences/$BUNDLE_ID.plist"
killall cfprefsd 2>/dev/null || true

echo "==> 3/6 Update source"
git pull --ff-only origin "$(git rev-parse --abbrev-ref HEAD)" || echo "(git pull skipped)"

echo "==> 4/6 Clean build"
rm -rf build
if [ -n "${TEAMID:-}" ]; then
  SIGN=(DEVELOPMENT_TEAM="$TEAMID" CODE_SIGN_STYLE=Automatic -allowProvisioningUpdates)
else
  SIGN=(CODE_SIGN_IDENTITY="-" CODE_SIGNING_REQUIRED=NO CODE_SIGNING_ALLOWED=YES)
fi
if ! xcodebuild -project Thock.xcodeproj -scheme Thock -configuration Release \
      -derivedDataPath build "${SIGN[@]}" build > build.log 2>&1; then
  echo "Build failed. Last errors:"; grep -E "error:" build.log | tail -20; echo "(full log: build.log)"; exit 1
fi

echo "==> 5/6 Install"
cp -R build/Build/Products/Release/LangThock.app "$APP"
xattr -cr "$APP"

echo "==> 6/6 Launch"
open "$APP"
cat <<MSG

Done. Now:
  1. Open System Settings > Privacy & Security > Accessibility
  2. Remove any old LangThock/Thock entries with the "-" button
  3. Enable LangThock (use the button in the window LangThock shows)
MSG
