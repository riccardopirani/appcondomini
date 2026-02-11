#!/usr/bin/env bash
set -euo pipefail

# Build iOS IPA (release) for App Store Connect.
# Usage:
#   ./build_ios_release.sh
#   ./build_ios_release.sh --build-name 1.1.1 --build-number 9

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

BUILD_NAME=""
BUILD_NUMBER=""

while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-name)  BUILD_NAME="${2:-}"; shift 2 ;;
    --build-number) BUILD_NUMBER="${2:-}"; shift 2 ;;
    -h|--help)
      echo "Usage: ./build_ios_release.sh [--build-name X.Y.Z] [--build-number N]"
      exit 0 ;;
    *) echo "Unknown argument: $1" >&2; exit 2 ;;
  esac
done

echo "🧹 Flutter clean..."
flutter clean

echo "📦 Flutter pub get..."
flutter pub get

EXTRA_ARGS=()
[[ -n "$BUILD_NAME" ]]   && EXTRA_ARGS+=(--build-name "$BUILD_NAME")
[[ -n "$BUILD_NUMBER" ]] && EXTRA_ARGS+=(--build-number "$BUILD_NUMBER")

echo "🍏 Building iOS IPA (release)..."
flutter build ipa --release "${EXTRA_ARGS[@]}"

echo ""
echo "✅ iOS build complete!"
echo "📁 IPA output:"
ls -lh build/ios/ipa/*.ipa
echo ""
echo "📤 Upload with Apple Transporter or Xcode Organizer."
