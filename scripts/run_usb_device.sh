#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

if [[ ! -f "pubspec.yaml" ]]; then
  echo "Errore: non trovo pubspec.yaml. Esegui lo script nella root del progetto Flutter." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Errore: comando 'flutter' non trovato nel PATH." >&2
  exit 1
fi

if ! command -v python3 >/dev/null 2>&1; then
  echo "Errore: comando 'python3' non trovato nel PATH." >&2
  exit 1
fi

DEVICE_ID="$(
  flutter devices --machine | python3 -c '
import json
import sys

try:
    devices = json.load(sys.stdin)
except Exception:
    print("")
    raise SystemExit(0)

for d in devices:
    is_emulator = d.get("emulator")
    platform = (d.get("targetPlatform") or "").lower()
    if is_emulator is False and (platform.startswith("android") or platform.startswith("ios")):
        print(d.get("id", ""))
        raise SystemExit(0)

print("")
'
)"

if [[ -z "${DEVICE_ID}" ]]; then
  echo "Nessun telefono fisico rilevato via USB."
  echo "Collega il dispositivo e verifica con: flutter devices"
  exit 1
fi

echo "==> Avvio su dispositivo: ${DEVICE_ID}"
flutter run -d "${DEVICE_ID}" "$@"
