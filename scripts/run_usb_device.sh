#!/bin/bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

if [[ ! -f "pubspec.yaml" ]]; then
  echo "Errore: non trovo pubspec.yaml. Esegui lo script dalla root del progetto Flutter." >&2
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

# Esclude gli ID elencati come (wireless) nell'output di `flutter devices`,
# così si usa il telefono collegato via cavo quando ce ne sono più di uno.
DEVICE_ID="$(
  ROOT_DIR="$ROOT_DIR" python3 <<'PY'
import json
import os
import re
import subprocess

root = os.environ["ROOT_DIR"]


def run_flutter(args):
    r = subprocess.run(
        ["flutter", *args],
        cwd=root,
        capture_output=True,
        text=True,
    )
    return (r.stdout or "") + (r.stderr or "")


text = run_flutter(["devices"])
wireless_ids = set()
for line in text.splitlines():
    if "(wireless)" in line.lower():
        m = re.search(r"•\s*([^\s•]+)\s*•", line)
        if m:
            wireless_ids.add(m.group(1).strip())

raw = run_flutter(["devices", "--machine"])
try:
    devices = json.loads(raw)
except Exception:
    print("")
    raise SystemExit(0)

for d in devices:
    if d.get("emulator") is not False:
        continue
    platform = (d.get("targetPlatform") or "").lower()
    if not (platform.startswith("android") or platform.startswith("ios")):
        continue
    dev_id = (d.get("id") or "").strip()
    if not dev_id or dev_id in wireless_ids:
        continue
    print(dev_id)
    break
else:
    print("")
PY
)"

if [[ -z "${DEVICE_ID}" ]]; then
  echo "Nessun telefono fisico via USB disponibile (o tutti risultano solo wireless)." >&2
  echo "Collega il dispositivo con il cavo, sbloccalo, e verifica con: flutter devices" >&2
  echo "Se compare solo '(wireless)', disattiva il debug wireless in Xcode o usa il cavo." >&2
  exit 1
fi

echo "==> Avvio su dispositivo (non wireless): ${DEVICE_ID}"
flutter run -d "${DEVICE_ID}" "$@"
