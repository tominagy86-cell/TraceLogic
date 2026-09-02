#!/usr/bin/env bash
# Kölcsön Apple gépen, első futtatás. Előállítja az .xcodeproj-t és megnyitja.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT"

if ! command -v xcodegen >/dev/null 2>&1; then
  echo "xcodegen telepítése (Homebrew)..."
  if ! command -v brew >/dev/null 2>&1; then
    echo "Nincs Homebrew. Telepítsd: https://brew.sh   majd futtasd újra."
    exit 1
  fi
  brew install xcodegen
fi

NAME="$(python3 -c 'import json;print(json.load(open("project.config.json"))["projectName"])')"

echo "xcodegen generate ($NAME)..."
xcodegen generate

echo "HealthCore tesztek (SPM)..."
swift test --package-path Packages/HealthCore || true

open "${NAME}.xcodeproj"
echo
echo "Xcode-ban:  Signing & Capabilities -> válaszd ki a Team-et (személyes Apple ID is jó),"
echo "majd válaszd ki a saját iPhone-odat és Cmd+R."
