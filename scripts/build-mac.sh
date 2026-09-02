#!/usr/bin/env bash
# Gyors build/teszt ellenőrzés a kölcsön Apple gépen.
# Használat:
#   ./scripts/build-mac.sh sim      # build + teszt iOS szimulátoron
#   ./scripts/build-mac.sh device   # build a csatlakoztatott iPhone-ra (aláírás kell)
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"
MODE="${1:-sim}"

NAME="$(python3 -c 'import json;print(json.load(open("project.config.json"))["projectName"])')"
command -v xcodegen >/dev/null 2>&1 && xcodegen generate

swift test --package-path Packages/HealthCore

case "$MODE" in
  sim)
    xcodebuild \
      -project "${NAME}.xcodeproj" \
      -scheme "${NAME}" \
      -destination 'platform=iOS Simulator,name=iPhone 16' \
      clean build test
    ;;
  device)
    xcodebuild \
      -project "${NAME}.xcodeproj" \
      -scheme "${NAME}" \
      -destination 'generic/platform=iOS' \
      -allowProvisioningUpdates \
      clean build
    ;;
  *)
    echo "ismeretlen mód: $MODE (sim | device)"; exit 1 ;;
esac
