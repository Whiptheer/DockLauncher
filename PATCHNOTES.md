# Patch notes

## v1.1.0 — November 18, 2026

### New
- **App reordering**: a new list in Preferences, with drag and drop, Move up / Move down buttons and "Reset to Dock order". The order is stored by the app and **does not change your Dock**.
- **Preferences window**: graphical settings for the shortcut and the "Ignore Finder" option.
- **8 languages**: English, French, Spanish, German, Japanese, Simplified Chinese, Portuguese and Russian, following the Mac's language.
- **Manual language choice**: a "Language" submenu and a list in Preferences, with "System default" selected by default. Changes apply instantly and are remembered.

### Improved
- **A single menu** for every kind of click on the menu bar icon (left click now opens the same menu as right click). The app list now lives in Preferences.
- **New, more subdued app icon**: a stylized Dock on a graphite background, with the first tile in blue.
- **New menu bar icon**: same motif, monochrome, adapting to light and dark mode.
- **More robust `build.sh`**: installs the icons and translations (even when kept in a subfolder), reports how many languages were found, refreshes the Finder's icon cache and works from any folder.
- `Info.plist`: languages declared, version bumped to 1.1.0.

### Fixed
- The compiled app had **no icon**: the `CFBundleIconFile` key and the icon copy step in `build.sh` were missing.
- In Preferences, the "Ignore Finder" checkbox and the shortcut dropdown could be mixed up when the window refreshed.

### Upgrading from v1.0.0
- Your settings (key combination, "Ignore Finder") are kept.
- To build, you now also need `AppIcon.icns`, the two `MenuBarIcon*.png` files and the `Localizable_*.strings` files next to `build.sh`.

---

## v1.0.0 — August 25, 2026

- Global shortcuts **⌘⌥1 to ⌘⌥9** to launch the apps in the Dock (Finder in position 1).
- Menu bar icon: left click for the app list, right click for settings.
- Choice of key combination among 4 (⌘⌥, ⌘⌃, ⌘⇧, ⌘⇧⌥).
- "Ignore Finder" option.
- Settings saved between launches.
- App packaged as a real `.app` (`build.sh` + `Info.plist`), with no Dock icon.
