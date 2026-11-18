# Patch notes

## v2.0.1 — November 18, 2026

### New
- **Clickable HUD app icons**: hold **⌘ + Option** and click an app icon in the floating shortcut menu to run the same action as its number shortcut.
- **Four-state Finder shortcut handling**: distinguishes a visible Finder window, a background or hidden visible window, an off-screen/minimized window and no Finder window.

### Improved
- Global shortcut handling now dispatches actions on the main thread and re-registers the hotkeys after the Mac wakes from sleep.
- Holding **⌘ + Option** for about half a second opens the floating shortcut menu; release the modifiers to close it.
- Finder window detection uses `CGWindowListCopyWindowInfo` and filters by PID, window layer and dimensions above `100 × 100`.

### Fixed
- A frontmost Finder window is hidden by the first shortcut press.
- A visible Finder window in the background or hidden state is restored with `activateIgnoringOtherApps`.
- An off-screen or minimized window is reopened through `NSWorkspace.openApplication`.
- When no Finder window exists, LaunchServices opens `FileManager.default.homeDirectoryForCurrentUser` through the Finder.

### Removed
- No Accessibility, Screen Recording, Input Monitoring, AppleScript or Automation permission is requested.
- No `kCGWindowName`, Accessibility API, event-tap, AppleScript or ScriptingBridge code is used.

### Requirements
- macOS 11 or later.
- No Accessibility permission.
- No Accessibility event tap.
- Existing UserDefaults settings are preserved.

## v2.0.0 — November 18, 2026

### New
- **10 shortcut slots** with support for keys 1 through 0.
- **Universal arm64/x86_64 build**.
- **Liquid Glass-style menu bar panel** with an AppKit fallback.
- **Floating shortcut menu / hold-to-peek HUD** showing Dock apps followed by active undocked apps. Hold the configured modifier combination for about half a second to open it; by default, hold **⌘⌥**. Release the modifiers to close it.
- **Option + click to quit** in the menu bar interface.
- **Active app indicators** for running applications.

### Improved
- The menu is shorter and fully localized in eight languages.
- The "Ignore Finder" setting remains available in Preferences.
- French menu wording is shorter: **Option + clic pour quitter**.

### Fixed
- **Finder shortcut behavior** now hides an active Finder instance on the first press.
- The second press restores the already-open Finder instance without opening a duplicate.
- Finder creates a new window only when no Finder window exists.
- Persisted shortcut modifier values outside the supported range are safely reset to the default.

### Removed
- Removed all Automation and AppleScript dependencies.
- Removed all Apps Management prompts and workflow.
- Finder and app behavior now use `NSRunningApplication`, `NSWorkspace` and `CGWindowListCopyWindowInfo` only.

### Requirements
- macOS 11 or later.
- No Accessibility permission.
- No Accessibility event tap.
- Existing UserDefaults settings are preserved.

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
