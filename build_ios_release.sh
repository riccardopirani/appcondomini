#!/usr/bin/env bash
set -eo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$ROOT_DIR"

# Legge versione e build correnti da pubspec.yaml
CURRENT_VERSION=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f1)
CURRENT_BUILD=$(grep '^version:' pubspec.yaml | sed 's/version: //' | cut -d'+' -f2)

echo "📋 Versione corrente: $CURRENT_VERSION+$CURRENT_BUILD"

# Incrementa automaticamente il build number
NEW_BUILD=$((CURRENT_BUILD + 1))

# Sovrascrive se passati come argomento
while [[ $# -gt 0 ]]; do
  case "$1" in
    --build-name)  CURRENT_VERSION="$2"; shift 2 ;;
    --build-number) NEW_BUILD="$2"; shift 2 ;;
    -h|--help)
      echo "Usage: ./build_ios_release.sh [--build-name X.Y.Z] [--build-number N]"
      echo ""
      echo "Senza argomenti: incrementa automaticamente il build number."
      exit 0 ;;
    *) echo "Unknown argument: $1"; exit 2 ;;
  esac
done

echo "🔄 Aggiornamento pubspec.yaml: $CURRENT_VERSION+$NEW_BUILD"
sed -i '' "s/^version: .*/version: $CURRENT_VERSION+$NEW_BUILD/" pubspec.yaml

echo "🧹 Flutter clean..."
flutter clean

echo "📦 Flutter pub get..."
flutter pub get

echo "🍏 Building iOS IPA (release) v$CURRENT_VERSION build $NEW_BUILD..."
flutter build ipa --release --build-name "$CURRENT_VERSION" --build-number "$NEW_BUILD"

echo ""
echo "✅ Build completata! v$CURRENT_VERSION+$NEW_BUILD"
ls -lh build/ios/ipa/*.ipa
echo ""
echo "📤 Carica con Apple Transporter o Xcode Organizer."
