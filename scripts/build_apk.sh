#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

if [[ ! -f "pubspec.yaml" ]]; then
  echo "Errore: non riesco a trovare pubspec.yaml. Assicurati di eseguire lo script dalla root del progetto Flutter." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Errore: comando flutter non trovato. Installa Flutter o aggiungilo al PATH." >&2
  exit 1
fi

echo "==> Versione Flutter"
flutter --version

echo "==> Pulizia progetto"
flutter clean

echo "==> Download dipendenze"
flutter pub get

APK_DIR="build/app/outputs/flutter-apk"
mkdir -p "$APK_DIR"

# --split-per-abi confligge con ndk.abiFilters in android/app/build.gradle;
# compiliamo ogni ABI separatamente con --target-platform.
declare -a BUILDS=(
  "android-arm:armeabi-v7a"
  "android-arm64:arm64-v8a"
  "android-x64:x86_64"
)

APK_PATHS=()

echo "==> Generazione APK debug (tutte le ABI)"
for entry in "${BUILDS[@]}"; do
  platform="${entry%%:*}"
  suffix="${entry##*:}"
  echo "==> Build debug: ${suffix} (${platform})"
  flutter build apk --debug --target-platform "$platform" "$@"
  cp "${APK_DIR}/app-debug.apk" "${APK_DIR}/app-${suffix}-debug.apk"
  APK_PATHS+=("${APK_DIR}/app-${suffix}-debug.apk")
done

echo "==> APK debug generati:"
for apk in "${APK_PATHS[@]}"; do
  echo "    $ROOT_DIR/$apk"
done
