#!/bin/bash
set -e

APP_NAME="DockLauncher"
APP_DIR="$APP_NAME.app"

# Se placer dans le dossier du script, peu importe d'où on le lance
cd "$(dirname "$0")"

rm -rf "$APP_DIR"
mkdir -p "$APP_DIR/Contents/MacOS"
mkdir -p "$APP_DIR/Contents/Resources"

cp Info.plist "$APP_DIR/Contents/Info.plist"

# Icône de l'app : AppIcon.icns en priorité, sinon génération depuis AppIcon.iconset
if [ -f "AppIcon.icns" ]; then
    cp AppIcon.icns "$APP_DIR/Contents/Resources/AppIcon.icns"
elif [ -d "AppIcon.iconset" ]; then
    iconutil -c icns AppIcon.iconset -o "$APP_DIR/Contents/Resources/AppIcon.icns"
else
    echo "ERREUR : ni AppIcon.icns ni AppIcon.iconset trouvés dans $(pwd)"
    echo "Ajoute-les au dossier (et commit-les sur GitHub) puis relance."
    exit 1
fi

# Icône de la barre des menus (chargée via NSImage(named:))
cp MenuBarIcon.png "$APP_DIR/Contents/Resources/"
cp MenuBarIcon@2x.png "$APP_DIR/Contents/Resources/"

# Traductions : Localizable_<langue>.strings -> <langue>.lproj/Localizable.strings
# (cherchées à côté du script ou dans un sous-dossier, ex. Localizations/)
LANG_COUNT=0
while IFS= read -r f; do
    name="$(basename "$f")"
    lang="${name#Localizable_}"
    lang="${lang%.strings}"
    mkdir -p "$APP_DIR/Contents/Resources/$lang.lproj"
    cp "$f" "$APP_DIR/Contents/Resources/$lang.lproj/Localizable.strings"
    LANG_COUNT=$((LANG_COUNT + 1))
done < <(find . -maxdepth 2 -name 'Localizable_*.strings')

echo "Traductions installées : $LANG_COUNT langue(s)"
if [ "$LANG_COUNT" = "0" ]; then
    echo "ATTENTION : aucun fichier Localizable_*.strings trouvé -> l'app sera uniquement en anglais."
    echo "Place les fichiers du zip à côté de build.sh (ou dans un sous-dossier) et relance."
fi

echo "Compilation..."
swiftc DockLauncher.swift -target arm64-apple-macos11.0 -o "$APP_DIR/Contents/MacOS/$APP_NAME.arm64"
swiftc DockLauncher.swift -target x86_64-apple-macos11.0 -o "$APP_DIR/Contents/MacOS/$APP_NAME.x86_64"
lipo -create \
    "$APP_DIR/Contents/MacOS/$APP_NAME.arm64" \
    "$APP_DIR/Contents/MacOS/$APP_NAME.x86_64" \
    -output "$APP_DIR/Contents/MacOS/$APP_NAME"
rm "$APP_DIR/Contents/MacOS/$APP_NAME.arm64" "$APP_DIR/Contents/MacOS/$APP_NAME.x86_64"

echo "Signature ad-hoc..."
xattr -cr "$APP_DIR"
rm -rf "$APP_DIR/Contents/_CodeSignature"

find "$APP_DIR" -xdev -print0 | while IFS= read -r -d '' f; do
    xattr -d com.apple.FinderInfo "$f" 2>/dev/null || true
    xattr -d com.apple.fileprovider.fpfs "$f" 2>/dev/null || true
    xattr -d com.apple.macl "$f" 2>/dev/null || true
    xattr -d com.apple.provenance "$f" 2>/dev/null || true
done

codesign --force --sign - "$APP_DIR/Contents/MacOS/$APP_NAME"

find "$APP_DIR" -xdev -print0 | while IFS= read -r -d '' f; do
    xattr -d com.apple.FinderInfo "$f" 2>/dev/null || true
    xattr -d com.apple.fileprovider.fpfs "$f" 2>/dev/null || true
    xattr -d com.apple.macl "$f" 2>/dev/null || true
    xattr -d com.apple.provenance "$f" 2>/dev/null || true
done

codesign --force --sign - "$APP_DIR"

echo ""
echo "Terminé : $APP_DIR est prêt."
echo "Premier lancement : clic droit sur l'app > Ouvrir (pour contourner Gatekeeper)."
