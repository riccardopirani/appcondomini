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

echo "==> Generazione APK (release)"
flutter build apk --release "$@"

APK_PATH="build/app/outputs/flutter-apk/app-release.apk"

if [[ -f "$APK_PATH" ]]; then
  echo "==> APK generato correttamente in: $ROOT_DIR/$APK_PATH"
else
  echo "Attenzione: build completata ma non trovo l'APK atteso in $ROOT_DIR/$APK_PATH" >&2
fi

