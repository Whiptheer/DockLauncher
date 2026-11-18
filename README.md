# DockLauncher

Launch the apps in your Dock with a keyboard shortcut: **⌘⌥1** opens the first one, **⌘⌥2** the second, and so on up to 9.

DockLauncher lives in the menu bar (no Dock icon) and runs on Apple Silicon Macs (M1 and later).

## Features

- **Global shortcuts ⌘⌥1 to ⌘⌥9**: they work from any app. Position 1 is Finder, followed by the apps pinned in your Dock, in Dock order.
- **Choose your key combination**: ⌘⌥, ⌘⌃, ⌘⇧ or ⌘⇧⌥ (applied immediately, no restart).
- **Custom order**: reorder the apps by drag and drop (or with the Move up / Move down buttons) **without changing your Dock's order**.
- **"Ignore Finder" option**: position 1 then goes to your first real app.
- **8 interface languages**: English, French, Spanish, German, Japanese, Simplified Chinese, Portuguese and Russian. It follows your Mac's language by default, and you can pick another one from the menu or the Preferences window.
- **A single menu** when you click the menu bar icon (left or right click): shortcut, Finder, language, Preferences, Quit.
- **Settings are saved** automatically.

## Installation

### From a release (easiest)

1. Download `DockLauncher-vX.Y.Z.zip` from the [Releases](https://github.com/Whiptheer/DockLauncher/releases) page.
2. Unzip it and drag `DockLauncher.app` into `/Applications`.
3. First launch: the app is not notarized by Apple, so macOS will block it.
   - Open **System Settings > Privacy & Security**, scroll down to the message about DockLauncher and click **Open Anyway**.
   - If the app is reported as "damaged", open Terminal and run: `xattr -dr com.apple.quarantine /Applications/DockLauncher.app`
4. To start it with your session: **System Settings > General > Login Items**, then add `DockLauncher.app`.

> The release binary is built for **Apple Silicon (arm64)**. On an Intel Mac, build from source (see below).

### From source

Requirements: macOS 11 or later and the command line tools (`xcode-select --install`).

```
git clone https://github.com/Whiptheer/DockLauncher.git
cd DockLauncher
chmod +x build.sh
./build.sh
```

The script creates `DockLauncher.app` in the folder. It prints `Traductions installées : 8 langue(s)` when the language files were found (the message itself is in French).

## Usage

- Press **⌘⌥ + a number** to launch the matching app.
- Click the menu bar icon to change the key combination, toggle "Ignore Finder", change the language or open Preferences.
- In **Preferences…**, the list shows each app with its shortcut. Drag a row to move it; **Reset to Dock order** removes your custom order.

Good to know:
- Only the first 9 rows have a shortcut (the following ones show "—").
- An app added to the Dock appears at the end of the list; an app removed from the Dock disappears.
- ⌘⌥8 is also the macOS Accessibility zoom shortcut, if you have it enabled.
- No special permission (Accessibility, etc.) should normally be required.

## Repository contents

| File | Purpose |
|---|---|
| `DockLauncher.swift` | App source code |
| `Info.plist` | App metadata (version, icon, languages) |
| `build.sh` | Assembles, compiles and signs `DockLauncher.app` |
| `AppIcon.icns` | App icon (`AppIcon.iconset`: source PNGs, optional) |
| `MenuBarIcon.png`, `MenuBarIcon@2x.png` | Menu bar icon |
| `Localizable_xx.strings` | Translations (one per language) |
| `PATCHNOTES.md` | Version history |

## Adding a language

1. Copy `Localizable_en.strings` to `Localizable_<code>.strings` (for example `Localizable_it.strings`) and translate what is on the right of the `=` sign.
2. Add the code to `CFBundleLocalizations` in `Info.plist`.
3. Add a line to `languageOptions` in `DockLauncher.swift`, with the language's name written in that language.
4. Run `./build.sh` again.

## Uninstalling

Quit the app from its menu and delete `DockLauncher.app`. To also erase its settings: `defaults delete com.noam.docklauncher`
