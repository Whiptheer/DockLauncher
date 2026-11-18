# DockLauncher

Launch apps from your Dock with a global keyboard shortcut. DockLauncher keeps a compact menu bar icon and works on macOS 11 or later without Accessibility permissions.

## Features

- **10 global shortcuts**: the default combination is **⌘⌥1** through **⌘⌥9**, plus **⌘⌥0**.
- **Dock-aware app order**: Finder is first, followed by pinned Dock apps in Dock order.
- **Active app indicators**: running apps outside the Dock fill the remaining shortcut slots.
- **Option + click to quit**: hold Option while clicking the menu bar icon, then choose Quit.
- **Floating shortcut menu / hold-to-peek HUD**: hold the configured modifier combination for about half a second to open the floating app menu. By default, hold **⌘⌥**. Release the modifiers to close it.
- **Clickable floating app icons**: click an icon while holding **⌘ + Option** to activate the app exactly as if you had typed its number shortcut.
- **Finder-aware behavior**: pressing the Finder shortcut hides an active Finder window, and pressing it again restores that window without opening an unnecessary duplicate.
- **Preferences**: choose the shortcut combination, exclude apps, ignore Finder, reorder apps, or reset to Dock order.
- **8 languages**: English, French, Spanish, German, Japanese, Simplified Chinese, Portuguese and Russian.
- **Universal build**: arm64 and x86_64 in one app bundle.
- **Liquid Glass interface** with an AppKit fallback.
- **No Accessibility permission** and no automation/AppleScript dependency.

## Installation

### From a release

1. Download `DockLauncher-v2.0.1.zip` from the [Releases](https://github.com/Whiptheer/DockLauncher/releases) page.
2. Unzip it and move `DockLauncher.app` to `/Applications`.
3. On the first launch, macOS may open Privacy & Security instead of launching the app because the release uses an ad-hoc signature.
4. Open **System Settings > Privacy & Security**, then click **Open Anyway** for DockLauncher.
5. Optionally add it to **System Settings > General > Login Items**.

### From source

Requirements: macOS 11 or later and Xcode Command Line Tools (`xcode-select --install`).

```bash
git clone https://github.com/Whiptheer/DockLauncher.git
cd DockLauncher
chmod +x build.sh
./build.sh
```

The script creates a universal `DockLauncher.app`, signs it ad-hoc and installs all icons and available translations.

## Usage

- Press the configured modifier combination plus a number to activate the app in that slot.
- Hold the configured modifier combination for about half a second to open the floating app menu. By default, hold **⌘⌥**; the menu closes when the modifiers are released. You can change the combination in Preferences.
- With **⌘ + Option** held, click an app icon in the floating menu to perform the same action as typing that app's number shortcut.
- Use the menu bar icon to open Preferences, change the language or quit.
- In Preferences, drag rows to reorder apps or reset the app order to the Dock order.
- Enable **Ignore Finder** to remove Finder from the shortcut list.

No Accessibility, Automation, AppleScript or Apps Management permission is requested.

## Privacy and security

DockLauncher uses `NSRunningApplication`, `NSWorkspace` and window information from `CGWindowListCopyWindowInfo` only. It does not install an event tap, collect keystrokes, access Accessibility APIs or make network requests.

## Repository contents

| File | Purpose |
|---|---|
| `DockLauncher.swift` | Single-file Swift/AppKit application source |
| `Info.plist` | App metadata, version and declared languages |
| `build.sh` | Universal build and ad-hoc signing script |
| `AppIcon.icns` | App icon |
| `MenuBarIcon.png`, `MenuBarIcon@2x.png` | Menu bar icons |
| `Localizations/Localizable_*.strings` | Translations |
| `PATCHNOTES.md` | English version history |

## Uninstalling

Quit DockLauncher from its menu and move `DockLauncher.app` to the Trash. To remove saved settings:

```bash
defaults delete com.noam.docklauncher
```
