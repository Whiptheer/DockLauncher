import Cocoa
import Carbon

struct ModifierOption {
    let title: String
    let flags: UInt32
}

let modifierOptions: [ModifierOption] = [
    ModifierOption(title: "⌘⌥  (Cmd + Option)", flags: UInt32(cmdKey | optionKey)),
    ModifierOption(title: "⌘⌃  (Cmd + Control)", flags: UInt32(cmdKey | controlKey)),
    ModifierOption(title: "⌘⇧  (Cmd + Shift)", flags: UInt32(cmdKey | shiftKey)),
    ModifierOption(title: "⌘⇧⌥  (Cmd + Shift + Option)", flags: UInt32(cmdKey | shiftKey | optionKey)),
]

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    var hotKeyRefs: [EventHotKeyRef?] = []
    var statusItem: NSStatusItem!
    var settingsWindow: NSWindow?
    let appsMenu = NSMenu()
    let settingsMenu = NSMenu()

    let keyCodes: [Int: UInt32] = [
        1: 18, 2: 19, 3: 20, 4: 21, 5: 23,
        6: 22, 7: 26, 8: 28, 9: 25
    ]

    // MARK: - Préférences persistées

    var selectedModifierIndex: Int {
        get { UserDefaults.standard.integer(forKey: "modifierIndex") } // 0 par défaut = ⌘⌥
        set { UserDefaults.standard.set(newValue, forKey: "modifierIndex") }
    }

    var ignoreFinder: Bool {
        get { UserDefaults.standard.bool(forKey: "ignoreFinder") }
        set { UserDefaults.standard.set(newValue, forKey: "ignoreFinder") }
    }

    // MARK: - Cycle de vie

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        installEventHandler()
        registerHotKeys()
    }

    // MARK: - Barre des menus (clic gauche vs clic droit)

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "DockLauncher")
            }
            button.target = self
            button.action = #selector(statusItemClicked(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        appsMenu.delegate = self
        settingsMenu.delegate = self
    }

    @objc func statusItemClicked(_ sender: Any) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            statusItem.menu = settingsMenu
        } else {
            statusItem.menu = appsMenu
        }
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        // On détache le menu pour pouvoir choisir lequel afficher au prochain clic
        statusItem.menu = nil
    }

    // MARK: - Menu clic gauche : liste des apps

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === appsMenu {
            buildAppsMenu()
        } else if menu === settingsMenu {
            buildSettingsMenu()
        }
    }

    func buildAppsMenu() {
        appsMenu.removeAllItems()
        let apps = getDockApps()
        let modifierTitle = modifierOptions[selectedModifierIndex].title.components(separatedBy: " ").first ?? "⌘⌥"

        if apps.isEmpty {
            appsMenu.addItem(NSMenuItem(title: "Aucune app détectée dans le Dock", action: nil, keyEquivalent: ""))
        } else {
            for i in 1...9 where i - 1 < apps.count {
                let url = apps[i - 1]
                let name = FileManager.default.displayName(atPath: url.path)
                let item = NSMenuItem(title: "\(modifierTitle)\(i)   \(name)",
                                       action: #selector(launchFromMenu(_:)),
                                       keyEquivalent: "")
                item.tag = i
                item.target = self
                appsMenu.addItem(item)
            }
        }

        appsMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quitter DockLauncher", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        appsMenu.addItem(quitItem)
    }

    @objc func launchFromMenu(_ sender: NSMenuItem) {
        let apps = getDockApps()
        let index = sender.tag
        if index > 0 && index <= apps.count {
            NSWorkspace.shared.open(apps[index - 1])
        }
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    // MARK: - Menu clic droit : réglages

    func buildSettingsMenu() {
        settingsMenu.removeAllItems()

        let shortcutHeader = NSMenuItem(title: "Raccourci clavier", action: nil, keyEquivalent: "")
        shortcutHeader.isEnabled = false
        settingsMenu.addItem(shortcutHeader)

        for (index, option) in modifierOptions.enumerated() {
            let item = NSMenuItem(title: option.title, action: #selector(selectModifier(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = (index == selectedModifierIndex) ? .on : .off
            settingsMenu.addItem(item)
        }

        settingsMenu.addItem(NSMenuItem.separator())

        let ignoreItem = NSMenuItem(title: "Ignorer Finder", action: #selector(toggleIgnoreFinder(_:)), keyEquivalent: "")
        ignoreItem.target = self
        ignoreItem.state = ignoreFinder ? .on : .off
        settingsMenu.addItem(ignoreItem)

        settingsMenu.addItem(NSMenuItem.separator())
        let preferencesItem = NSMenuItem(title: "Préférences…", action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        settingsMenu.addItem(preferencesItem)

        settingsMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: "Quitter DockLauncher", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        settingsMenu.addItem(quitItem)
    }

    @objc func selectModifier(_ sender: NSMenuItem) {
        selectedModifierIndex = sender.tag
        registerHotKeys() // ré-applique immédiatement le nouveau raccourci
    }

    @objc func toggleIgnoreFinder(_ sender: NSMenuItem) {
        ignoreFinder.toggle()
    }

    @objc func showPreferences() {
        if settingsWindow == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 230),
                                  styleMask: [.titled, .closable],
                                  backing: .buffered,
                                  defer: false)
            window.title = "DockLauncher – Préférences"
            window.isReleasedWhenClosed = false
            window.center()

            let contentView = NSView(frame: NSRect(x: 0, y: 0, width: 440, height: 230))
            window.contentView = contentView

            let titleLabel = NSTextField(labelWithString: "Réglages de DockLauncher")
            titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
            titleLabel.frame = NSRect(x: 24, y: 184, width: 390, height: 24)
            contentView.addSubview(titleLabel)

            let shortcutLabel = NSTextField(labelWithString: "Raccourci clavier")
            shortcutLabel.frame = NSRect(x: 24, y: 137, width: 150, height: 20)
            contentView.addSubview(shortcutLabel)

            let shortcutPopup = NSPopUpButton(frame: NSRect(x: 190, y: 133, width: 220, height: 26))
            shortcutPopup.addItems(withTitles: modifierOptions.map(\.title))
            shortcutPopup.selectItem(at: selectedModifierIndex)
            shortcutPopup.target = self
            shortcutPopup.action = #selector(selectModifierFromPreferences(_:))
            contentView.addSubview(shortcutPopup)

            let finderCheckbox = NSButton(checkboxWithTitle: "Ignorer Finder dans la liste des applications",
                                          target: self,
                                          action: #selector(toggleIgnoreFinderFromPreferences(_:)))
            finderCheckbox.frame = NSRect(x: 24, y: 91, width: 390, height: 20)
            finderCheckbox.state = ignoreFinder ? .on : .off
            contentView.addSubview(finderCheckbox)

            let descriptionLabel = NSTextField(labelWithString: "Les changements sont appliqués immédiatement.")
            descriptionLabel.textColor = .secondaryLabelColor
            descriptionLabel.frame = NSRect(x: 24, y: 48, width: 390, height: 20)
            contentView.addSubview(descriptionLabel)

            settingsWindow = window
        }

        if let window = settingsWindow {
            if let shortcutPopup = window.contentView?.subviews.compactMap({ $0 as? NSPopUpButton }).first {
                shortcutPopup.selectItem(at: selectedModifierIndex)
            }
            if let finderCheckbox = window.contentView?.subviews.compactMap({ $0 as? NSButton }).first {
                finderCheckbox.state = ignoreFinder ? .on : .off
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc func selectModifierFromPreferences(_ sender: NSPopUpButton) {
        selectedModifierIndex = sender.indexOfSelectedItem
        registerHotKeys()
    }

    @objc func toggleIgnoreFinderFromPreferences(_ sender: NSButton) {
        ignoreFinder = sender.state == .on
    }

    // MARK: - Lecture de l'ordre du Dock

    func getDockApps() -> [URL] {
        var apps: [URL] = []

        if !ignoreFinder,
           let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
            apps.append(finderURL)
        }

        guard let dockDefaults = UserDefaults(suiteName: "com.apple.dock"),
              let persistentApps = dockDefaults.array(forKey: "persistent-apps") as? [[String: Any]] else {
            return apps
        }

        for entry in persistentApps {
            if let tileData = entry["tile-data"] as? [String: Any],
               let fileData = tileData["file-data"] as? [String: Any],
               let urlString = fileData["_CFURLString"] as? String,
               let url = URL(string: urlString) {
                apps.append(url)
            }
        }

        return apps
    }

    // MARK: - Raccourcis clavier globaux

    func installEventHandler() {
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                       eventKind: OSType(kEventHotKeyPressed))
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        InstallEventHandler(GetApplicationEventTarget(), { (_, event, userData) -> OSStatus in
            guard let userData = userData else { return noErr }
            let mySelf = Unmanaged<AppDelegate>.fromOpaque(userData).takeUnretainedValue()

            var hotKeyID = EventHotKeyID()
            GetEventParameter(event,
                               EventParamName(kEventParamDirectObject),
                               EventParamType(typeEventHotKeyID),
                               nil,
                               MemoryLayout<EventHotKeyID>.size,
                               nil,
                               &hotKeyID)

            let index = Int(hotKeyID.id)
            let apps = mySelf.getDockApps()

            if index > 0 && index <= apps.count {
                NSWorkspace.shared.open(apps[index - 1])
            }
            return noErr
        }, 1, &eventType, selfPtr, nil)
    }

    func unregisterHotKeys() {
        for ref in hotKeyRefs {
            if let ref = ref { UnregisterEventHotKey(ref) }
        }
        hotKeyRefs.removeAll()
    }

    func registerHotKeys() {
        unregisterHotKeys()
        let modifiers = modifierOptions[selectedModifierIndex].flags

        for (index, keyCode) in keyCodes {
            var hotKeyRef: EventHotKeyRef?
            let hotKeyID = EventHotKeyID(signature: OSType(0x646f636b), id: UInt32(index)) // 'dock'
            let status = RegisterEventHotKey(keyCode, modifiers, hotKeyID,
                                              GetApplicationEventTarget(), 0, &hotKeyRef)
            if status != noErr {
                print("Erreur enregistrement raccourci \(index): code \(status)")
            }
            hotKeyRefs.append(hotKeyRef)
        }
    }
}

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
