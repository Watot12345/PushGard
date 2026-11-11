#!/usr/bin/env bash
# Builds and verifies the PushGard GitHub Pages bundle (dist/gh-pages/)
# and optionally the Android release APK (--apk).
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT_DIR"

echo "==> [1/4] Verifying canonical thresholds.json sync..."
./scripts/sync_thresholds.sh --check

echo "==> [2/4] Running Flutter static analyzer and full E2E beta test suite..."
(
  cd "$ROOT_DIR/mobile"
  flutter analyze
  flutter test
)

echo "==> [3/4] Building Flutter Web release bundle for GitHub Pages..."
(
  cd "$ROOT_DIR/mobile"
  flutter build web --release
)

rm -rf "$ROOT_DIR/dist/gh-pages"
mkdir -p "$ROOT_DIR/dist/gh-pages/app"
cp "$ROOT_DIR/web-portal/index.html" "$ROOT_DIR/dist/gh-pages/index.html"
cp -r "$ROOT_DIR/mobile/build/web/"* "$ROOT_DIR/dist/gh-pages/app/"
sed -i 's|<base href="/">|<base href="./">|g' "$ROOT_DIR/dist/gh-pages/app/index.html"
touch "$ROOT_DIR/dist/gh-pages/.nojekyll"
echo "    GitHub Pages bundle staged at: dist/gh-pages/"

if [[ "${1:-}" == "--apk" ]]; then
  echo "==> [4/4] Building Android Universal Release APK..."
  (
    cd "$ROOT_DIR/mobile"
    flutter build apk --release
  )
  mkdir -p "$ROOT_DIR/dist/releases"
  cp "$ROOT_DIR/mobile/build/app/outputs/flutter-apk/app-release.apk" \
     "$ROOT_DIR/dist/releases/PushGard-v1.0.0-beta.1-android-universal.apk"
  (cd "$ROOT_DIR/dist/releases" && sha256sum PushGard-v1.0.0-beta.1-android-universal.apk > SHA256SUMS.txt)
  echo "    Android APK staged at: dist/releases/PushGard-v1.0.0-beta.1-android-universal.apk"
else
  echo "==> [4/4] Skipping local Android APK build (pass --apk to build local APK)."
fi

echo "==> DONE: PushGard release artifacts verified and ready to publish!"
