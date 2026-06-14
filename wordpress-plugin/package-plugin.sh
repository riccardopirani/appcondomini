#!/usr/bin/env bash
# Crea lo zip del plugin PdG App API pronto per upload su WordPress.
# Uso: ./package-plugin.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGIN_FILE="$SCRIPT_DIR/pdg-app-api.php"
OUT_DIR="$SCRIPT_DIR/dist"
VERSION="$(grep -m1 '^\s*\* Version:' "$PLUGIN_FILE" | sed 's/.*Version: //;s/ .*//')"
ZIP_NAME="pdg-app-api-${VERSION}.zip"
TMP_DIR="$(mktemp -d)"

mkdir -p "$OUT_DIR"
cp "$PLUGIN_FILE" "$TMP_DIR/pdg-app-api.php"
(
  cd "$TMP_DIR"
  zip -q "$OUT_DIR/$ZIP_NAME" pdg-app-api.php
)
rm -rf "$TMP_DIR"

echo "✅ Creato: $OUT_DIR/$ZIP_NAME"
echo "   Caricalo in WordPress → Plugin → Aggiungi nuovo → Carica plugin"
