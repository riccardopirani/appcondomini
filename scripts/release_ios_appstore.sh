#!/bin/bash
#
# Build IPA e upload su App Store Connect via Fastlane (locale).
#
# Prerequisiti:
#   - macOS con Xcode, Flutter, Ruby
#   - Certificato Apple Distribution + profilo App Store installati nel Keychain
#   - API key App Store Connect (consigliata) oppure login Apple ID in Xcode
#
# Uso:
#   ./scripts/release_ios_appstore.sh              # TestFlight (default)
#   ./scripts/release_ios_appstore.sh beta         # TestFlight
#   ./scripts/release_ios_appstore.sh release      # App Store Connect (senza review)
#   ./scripts/release_ios_appstore.sh build        # solo build IPA
#
# API key in locale (consigliato):
#   export APP_STORE_CONNECT_API_KEY_ID="XXXXXXXXXX"
#   export APP_STORE_CONNECT_ISSUER_ID="xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
#   export APP_STORE_CONNECT_API_KEY_PATH="$HOME/.appstoreconnect/AuthKey_XXXXXXXXXX.p8"
#
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")"/.. && pwd)"
cd "$ROOT_DIR"

LANE="${1:-beta}"

if [[ ! -f "pubspec.yaml" ]]; then
  echo "Errore: pubspec.yaml non trovato. Esegui lo script dalla root del progetto Flutter." >&2
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Errore: flutter non trovato nel PATH." >&2
  exit 1
fi

if [[ "$(uname -s)" != "Darwin" ]]; then
  echo "Errore: il rilascio iOS richiede macOS." >&2
  exit 1
fi

if ! command -v bundle >/dev/null 2>&1; then
  echo "Errore: bundle (Ruby) non trovato. Installa Ruby o usa: gem install bundler" >&2
  exit 1
fi

case "$LANE" in
  beta|release|build) ;;
  *)
    echo "Lane non valida: $LANE (usa beta, release o build)" >&2
    exit 1
    ;;
esac

echo "==> Versione Flutter"
flutter --version

echo "==> Versione app (pubspec.yaml)"
grep '^version:' pubspec.yaml

echo "==> Installazione gem Fastlane"
cd ios

if command -v rbenv >/dev/null 2>&1 && rbenv versions --bare 2>/dev/null | grep -q '^3\.'; then
  RBENV_VERSION="$(rbenv versions --bare | grep '^3\.' | tail -1)"
  export RBENV_VERSION
elif [[ -x /opt/homebrew/opt/ruby/bin/bundle ]]; then
  export PATH="/opt/homebrew/opt/ruby/bin:$PATH"
fi

bundle install

echo "==> Fastlane lane: $LANE"
bundle exec fastlane ios "$LANE"

echo "==> Completato"
