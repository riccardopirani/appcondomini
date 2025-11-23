#!/bin/bash

# Crea i file di cache mancanti per Xcode
DERIVED_DATA_DIR="$HOME/Library/Developer/Xcode/DerivedData"

# Crea il file di cache stat SDK
SDK_CACHE_DIR="$DERIVED_DATA_DIR/SDKStatCaches.noindex"
SDK_CACHE_FILE="$SDK_CACHE_DIR/iphonesimulator18.2-22C146-07b28473f605e47e75261259d3ef3b5a.sdkstatcache"
mkdir -p "$SDK_CACHE_DIR"
touch "$SDK_CACHE_FILE"

# Crea il file di validazione moduli
MODULE_CACHE_DIR="$DERIVED_DATA_DIR/ModuleCache.noindex"
MODULE_VALIDATION_FILE="$MODULE_CACHE_DIR/Session.modulevalidation"
mkdir -p "$MODULE_CACHE_DIR"
touch "$MODULE_VALIDATION_FILE"

exit 0

