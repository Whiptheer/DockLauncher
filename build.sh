#!/bin/bash
set -e

APP_NAME="DockLauncher"
APP_DIR="$APP_NAME.app"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp Info.plist "$APP_DIR/Contents/Info.plist"

echo "Compilation..."
swiftc DockLauncher.swift -o "$APP_DIR/Contents/MacOS/$APP_NAME"

echo "Signature ad-hoc..."
codesign --force --deep --sign - "$APP_DIR"

echo ""
echo "Terminé : $APP_DIR est prêt."
echo "Premier lancement : clic droit sur l'app > Ouvrir (pour contourner Gatekeeper)."
