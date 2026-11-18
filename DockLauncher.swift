import Cocoa
import Carbon

struct ModifierOption {
    let title: String
    let symbols: String
    let flags: UInt32
}

let modifierOptions: [ModifierOption] = [
    ModifierOption(title: "⌘⌥  (Cmd + Option)", symbols: "⌘⌥", flags: UInt32(cmdKey | optionKey)),
    ModifierOption(title: "⌘⌃  (Cmd + Control)", symbols: "⌘⌃", flags: UInt32(cmdKey | controlKey)),
    ModifierOption(title: "⌘⇧  (Cmd + Shift)", symbols: "⌘⇧", flags: UInt32(cmdKey | shiftKey)),
    ModifierOption(title: "⌘⇧⌥  (Cmd + Shift + Option)", symbols: "⌘⇧⌥", flags: UInt32(cmdKey | shiftKey | optionKey)),
]

let rowDragType = NSPasteboard.PasteboardType("com.noam.docklauncher.row")

struct LanguageOption {
    let code: String?   // nil = suivre la langue du système
    let name: String    // nom affiché dans sa propre langue
}

let languageOptions: [LanguageOption] = [
    LanguageOption(code: nil, name: ""),
    LanguageOption(code: "en", name: "English"),
    LanguageOption(code: "fr", name: "Français"),
    LanguageOption(code: "es", name: "Español"),
    LanguageOption(code: "de", name: "Deutsch"),
    LanguageOption(code: "ja", name: "日本語"),
    LanguageOption(code: "zh-Hans", name: "简体中文"),
    LanguageOption(code: "pt", name: "Português"),
    LanguageOption(code: "ru", name: "Русский"),
]

/// Traduction avec langue forcée par l'utilisateur (sinon langue du système).
func tr(_ key: String) -> String {
    if let code = UserDefaults.standard.string(forKey: "language"),
       let path = Bundle.main.path(forResource: code, ofType: "lproj"),
       let bundle = Bundle(path: path) {
        return bundle.localizedString(forKey: key, value: key, table: nil)
    }
    return Bundle.main.localizedString(forKey: key, value: key, table: nil)
}

class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate, NSTableViewDataSource, NSTableViewDelegate {
    var hotKeyRefs: [EventHotKeyRef?] = []
    var statusItem: NSStatusItem!
    let settingsMenu = NSMenu()
    var globalFlagsMonitor: Any?
    var localFlagsMonitor: Any?
    var peekTimer: DispatchWorkItem?
    var peekPanel: NSPanel?
    var finderWindowStateHidden = false

    // Fenêtre de préférences
    var settingsWindow: NSWindow?
    var shortcutPopup: NSPopUpButton?
    var languagePopup: NSPopUpButton?
    var finderCheckbox: NSButton?
    var orderTable: NSTableView?
    var prefApps: [URL] = []

    let keyCodes: [Int: UInt32] = [
        1: 18, 2: 19, 3: 20, 4: 21, 5: 23,
        6: 22, 7: 26, 8: 28, 9: 25, 10: 29
    ]

    // MARK: - Préférences persistées

    var selectedModifierIndex: Int {
        get {
            let value = UserDefaults.standard.integer(forKey: "modifierIndex")
            if modifierOptions.indices.contains(value) {
                return value
            }
            UserDefaults.standard.set(0, forKey: "modifierIndex")
            return 0
        }
        set {
            let safeValue = modifierOptions.indices.contains(newValue) ? newValue : 0
            UserDefaults.standard.set(safeValue, forKey: "modifierIndex")
        }
    }

    var ignoreFinder: Bool {
        get { UserDefaults.standard.bool(forKey: "ignoreFinder") }
        set { UserDefaults.standard.set(newValue, forKey: "ignoreFinder") }
    }

    var excludedAppPaths: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: "excludedAppPaths") ?? []) }
        set { UserDefaults.standard.set(Array(newValue).sorted(), forKey: "excludedAppPaths") }
    }

    var selectedLanguageIndex: Int {
        let current = UserDefaults.standard.string(forKey: "language")
        return languageOptions.firstIndex(where: { $0.code == current }) ?? 0
    }

    // MARK: - Cycle de vie

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        installEventHandler()
        registerHotKeys()
        installModifierMonitors()
    }

    deinit {
        unregisterHotKeys()
        cancelPeek()
        if let monitor = globalFlagsMonitor { NSEvent.removeMonitor(monitor) }
        if let monitor = localFlagsMonitor { NSEvent.removeMonitor(monitor) }
    }

    // MARK: - Barre des menus (même menu pour tous les types de clic)

    func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)

        if let button = statusItem.button {
            if let icon = NSImage(named: "MenuBarIcon") {
                icon.isTemplate = true
                button.image = icon
            } else {
                button.image = NSImage(systemSymbolName: "square.grid.3x3.fill", accessibilityDescription: "DockLauncher")
            }
        }

        settingsMenu.delegate = self
        statusItem.menu = settingsMenu
    }

    func menuNeedsUpdate(_ menu: NSMenu) {
        if menu === settingsMenu {
            buildSettingsMenu()
        }
    }

    func menuWillOpen(_ menu: NSMenu) {
        if menu === settingsMenu {
            buildSettingsMenu()
        }
    }

    func buildSettingsMenu() {
        settingsMenu.removeAllItems()

        let shortcutHeader = NSMenuItem(title: tr("Keyboard shortcut"), action: nil, keyEquivalent: "")
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

        let appsHeader = NSMenuItem(title: tr("Applications"), action: nil, keyEquivalent: "")
        appsHeader.isEnabled = false
        settingsMenu.addItem(appsHeader)

        let appsHint = NSMenuItem(title: tr("Option-click a running app to quit"), action: nil, keyEquivalent: "")
        appsHint.isEnabled = false
        settingsMenu.addItem(appsHint)

        let running = NSWorkspace.shared.runningApplications
        let runningBundles = Set(running.compactMap { $0.bundleIdentifier })
        for (slot, url) in getDockApps().prefix(10).enumerated() {
            let displayName = FileManager.default.displayName(atPath: url.path)
            guard let bundleID = Bundle(url: url)?.bundleIdentifier else { continue }
            let isRunning = runningBundles.contains(bundleID)
            let shortcutLabel = slot == 9 ? "0" : "\(slot + 1)"
            let title = (isRunning ? "● " : "") + "\(shortcutLabel). " + displayName
            let item = NSMenuItem(title: title, action: #selector(menuAppItemClicked(_:)), keyEquivalent: "")
            item.target = self
            item.representedObject = url
            item.isEnabled = true
            settingsMenu.addItem(item)
        }

        settingsMenu.addItem(NSMenuItem.separator())
        let languageItem = NSMenuItem(title: tr("Language"), action: nil, keyEquivalent: "")
        let languageSubmenu = NSMenu()
        for (index, option) in languageOptions.enumerated() {
            let title = option.code == nil ? tr("System default") : option.name
            let item = NSMenuItem(title: title, action: #selector(selectLanguage(_:)), keyEquivalent: "")
            item.target = self
            item.tag = index
            item.state = (index == selectedLanguageIndex) ? .on : .off
            languageSubmenu.addItem(item)
            if index == 0 { languageSubmenu.addItem(NSMenuItem.separator()) }
        }
        languageItem.submenu = languageSubmenu
        settingsMenu.addItem(languageItem)

        settingsMenu.addItem(NSMenuItem.separator())
        let preferencesItem = NSMenuItem(title: tr("Preferences…"), action: #selector(showPreferences), keyEquivalent: ",")
        preferencesItem.target = self
        settingsMenu.addItem(preferencesItem)

        settingsMenu.addItem(NSMenuItem.separator())
        let quitItem = NSMenuItem(title: tr("Quit DockLauncher"), action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        settingsMenu.addItem(quitItem)
    }

    @objc func quitApp() {
        NSApp.terminate(nil)
    }

    @objc func selectModifier(_ sender: NSMenuItem) {
        selectedModifierIndex = sender.tag
        registerHotKeys() // ré-applique immédiatement le nouveau raccourci
        refreshPreferences()
    }

    @objc func toggleIgnoreFinder(_ sender: NSMenuItem) {
        ignoreFinder.toggle()
        syncFinderExclusion(ignoreFinder)
        refreshPreferences()
    }

    @objc func menuAppItemClicked(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        if NSApp.currentEvent?.modifierFlags.contains(.option) == true {
            quitApplication(url)
        } else {
            activateApplication(url)
        }
    }

    @objc func menuAppQuitClicked(_ sender: NSMenuItem) {
        guard let url = sender.representedObject as? URL else { return }
        quitApplication(url)
    }

    // MARK: - Langue

    @objc func selectLanguage(_ sender: NSMenuItem) {
        applyLanguage(languageOptions[sender.tag].code)
    }

    @objc func selectLanguageFromPreferences(_ sender: NSPopUpButton) {
        applyLanguage(languageOptions[sender.indexOfSelectedItem].code)
    }

    func applyLanguage(_ code: String?) {
        if let code = code {
            UserDefaults.standard.set(code, forKey: "language")
        } else {
            UserDefaults.standard.removeObject(forKey: "language")
        }

        // La fenêtre de préférences est reconstruite pour prendre la nouvelle langue
        let wasVisible = settingsWindow?.isVisible ?? false
        let oldOrigin = settingsWindow?.frame.origin
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            self.settingsWindow?.close()
            self.settingsWindow = nil
            self.shortcutPopup = nil
            self.languagePopup = nil
            self.finderCheckbox = nil
            self.orderTable = nil
            if wasVisible {
                self.showPreferences()
                if let origin = oldOrigin { self.settingsWindow?.setFrameOrigin(origin) }
            }
        }
    }

    // MARK: - Fenêtre de préférences

    @objc func showPreferences() {
        if settingsWindow == nil {
            buildPreferencesWindow()
        }
        refreshPreferences()
        settingsWindow?.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func buildPreferencesWindow() {
        let width: CGFloat = 500
        let height: CGFloat = 596

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height),
                              styleMask: [.titled, .closable],
                              backing: .buffered,
                              defer: false)
        window.title = tr("DockLauncher – Preferences")
        window.isReleasedWhenClosed = false
        window.center()

        let contentView = NSView(frame: NSRect(x: 0, y: 0, width: width, height: height))
        window.contentView = contentView

        let titleLabel = NSTextField(labelWithString: tr("DockLauncher Settings"))
        titleLabel.font = NSFont.boldSystemFont(ofSize: 16)
        titleLabel.frame = NSRect(x: 24, y: 552, width: 452, height: 24)
        contentView.addSubview(titleLabel)

        let shortcutLabel = NSTextField(labelWithString: tr("Keyboard shortcut"))
        shortcutLabel.frame = NSRect(x: 24, y: 510, width: 150, height: 20)
        contentView.addSubview(shortcutLabel)

        let popup = NSPopUpButton(frame: NSRect(x: 190, y: 506, width: 286, height: 26))
        popup.addItems(withTitles: modifierOptions.map { $0.title })
        popup.target = self
        popup.action = #selector(selectModifierFromPreferences(_:))
        contentView.addSubview(popup)
        shortcutPopup = popup

        let languageLabel = NSTextField(labelWithString: tr("Language"))
        languageLabel.frame = NSRect(x: 24, y: 474, width: 150, height: 20)
        contentView.addSubview(languageLabel)

        let langPopup = NSPopUpButton(frame: NSRect(x: 190, y: 470, width: 286, height: 26))
        langPopup.addItems(withTitles: languageOptions.map { $0.code == nil ? tr("System default") : $0.name })
        langPopup.target = self
        langPopup.action = #selector(selectLanguageFromPreferences(_:))
        contentView.addSubview(langPopup)
        languagePopup = langPopup

        let checkbox = NSButton(checkboxWithTitle: tr("Ignore Finder in the app list"),
                                target: self,
                                action: #selector(toggleIgnoreFinderFromPreferences(_:)))
        checkbox.frame = NSRect(x: 24, y: 434, width: 452, height: 20)
        contentView.addSubview(checkbox)
        finderCheckbox = checkbox

        let sectionLabel = NSTextField(labelWithString: tr("App order"))
        sectionLabel.font = NSFont.boldSystemFont(ofSize: 13)
        sectionLabel.frame = NSRect(x: 24, y: 398, width: 452, height: 18)
        contentView.addSubview(sectionLabel)

        let hintLabel = NSTextField(labelWithString: tr("Drag and drop rows to reorder. Your Dock is not modified."))
        hintLabel.font = NSFont.systemFont(ofSize: 11)
        hintLabel.textColor = .secondaryLabelColor
        hintLabel.frame = NSRect(x: 24, y: 378, width: 452, height: 16)
        contentView.addSubview(hintLabel)

        // Tableau réordonnable
        let table = NSTableView()
        let excludedColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("excluded"))
        excludedColumn.title = tr("Use shortcut")
        excludedColumn.width = 82
        excludedColumn.minWidth = 82
        let shortcutColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("shortcut"))
        shortcutColumn.title = tr("Shortcut")
        shortcutColumn.width = 90
        shortcutColumn.minWidth = 70
        let appColumn = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("app"))
        appColumn.title = tr("Application")
        appColumn.width = 258
        table.addTableColumn(excludedColumn)
        table.addTableColumn(shortcutColumn)
        table.addTableColumn(appColumn)
        table.rowHeight = 30
        table.usesAlternatingRowBackgroundColors = true
        table.allowsMultipleSelection = false
        table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        table.dataSource = self
        table.delegate = self
        table.registerForDraggedTypes([rowDragType])
        table.draggingDestinationFeedbackStyle = .gap

        let scrollView = NSScrollView(frame: NSRect(x: 24, y: 64, width: 452, height: 304))
        scrollView.documentView = table
        scrollView.hasVerticalScroller = true
        scrollView.borderType = .bezelBorder
        contentView.addSubview(scrollView)
        orderTable = table

        let resetButton = NSButton(title: tr("Reset to Dock order"), target: self, action: #selector(resetOrder))
        resetButton.bezelStyle = .rounded
        resetButton.frame = NSRect(x: 24, y: 24, width: 216, height: 28)
        contentView.addSubview(resetButton)

        let upButton = NSButton(title: tr("↑ Move up"), target: self, action: #selector(moveSelectedUp))
        upButton.bezelStyle = .rounded
        upButton.frame = NSRect(x: 248, y: 24, width: 110, height: 28)
        contentView.addSubview(upButton)

        let downButton = NSButton(title: tr("↓ Move down"), target: self, action: #selector(moveSelectedDown))
        downButton.bezelStyle = .rounded
        downButton.frame = NSRect(x: 366, y: 24, width: 110, height: 28)
        contentView.addSubview(downButton)

        settingsWindow = window
    }

    func refreshPreferences() {
        shortcutPopup?.selectItem(at: selectedModifierIndex)
        languagePopup?.selectItem(at: selectedLanguageIndex)
        finderCheckbox?.state = ignoreFinder ? .on : .off
        prefApps = orderedApps()
        orderTable?.reloadData()
    }

    @objc func selectModifierFromPreferences(_ sender: NSPopUpButton) {
        selectedModifierIndex = sender.indexOfSelectedItem
        registerHotKeys()
        orderTable?.reloadData() // met à jour les libellés de raccourci
    }

    @objc func toggleIgnoreFinderFromPreferences(_ sender: NSButton) {
        ignoreFinder = (sender.state == .on)
        syncFinderExclusion(ignoreFinder)
        refreshPreferences()
    }

    @objc func toggleAppExclusion(_ sender: NSButton) {
        guard sender.tag >= 0 && sender.tag < prefApps.count else { return }
        let url = prefApps[sender.tag]
        var excluded = excludedAppPaths
        if sender.state == .off {
            excluded.insert(url.path)
        } else {
            excluded.remove(url.path)
        }
        excludedAppPaths = excluded
        if isFinder(url) {
            ignoreFinder = excluded.contains(url.path)
            finderCheckbox?.state = ignoreFinder ? .on : .off
        }
        registerHotKeys()
        refreshPreferences()
    }

    @objc func resetOrder() {
        UserDefaults.standard.removeObject(forKey: "customOrder")
        refreshPreferences()
    }

    @objc func moveSelectedUp() { moveSelected(by: -1) }
    @objc func moveSelectedDown() { moveSelected(by: 1) }

    func moveSelected(by delta: Int) {
        guard let table = orderTable else { return }
        let row = table.selectedRow
        guard row >= 0 else { return }
        let target = row + delta
        guard target >= 0 && target < prefApps.count else { return }
        prefApps.swapAt(row, target)
        saveOrder()
        table.reloadData()
        table.selectRowIndexes(IndexSet(integer: target), byExtendingSelection: false)
    }

    // MARK: - Tableau : source de données

    func numberOfRows(in tableView: NSTableView) -> Int {
        return prefApps.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        guard row < prefApps.count, let identifier = tableColumn?.identifier.rawValue else { return nil }
        let url = prefApps[row]
        let cell = NSTableCellView()

        let excluded = isExcluded(url)
        if identifier == "excluded" {
            let checkbox = NSButton(checkboxWithTitle: "", target: self, action: #selector(toggleAppExclusion(_:)))
            checkbox.tag = row
            checkbox.state = excluded ? .off : .on
            checkbox.translatesAutoresizingMaskIntoConstraints = false
            checkbox.toolTip = tr("Use shortcut")
            cell.addSubview(checkbox)
            NSLayoutConstraint.activate([
                checkbox.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 28),
                checkbox.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        } else if identifier == "shortcut" {
            var slot = 0
            for app in prefApps.prefix(row + 1) {
                if !isExcluded(app) { slot += 1 }
            }
            let hasShortcut = !excluded && slot >= 1 && slot <= 10
            let text = hasShortcut ? "\(modifierOptions[selectedModifierIndex].symbols)\(slot == 10 ? "0" : "\(slot)")" : "—"
            let label = NSTextField(labelWithString: text)
            label.font = NSFont.monospacedSystemFont(ofSize: 13, weight: .medium)
            label.textColor = hasShortcut ? .labelColor : .tertiaryLabelColor
            label.translatesAutoresizingMaskIntoConstraints = false
            cell.addSubview(label)
            NSLayoutConstraint.activate([
                label.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 6),
                label.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        } else {
            let iconView = NSImageView()
            iconView.image = NSWorkspace.shared.icon(forFile: url.path)
            iconView.translatesAutoresizingMaskIntoConstraints = false

            let name = NSTextField(labelWithString: FileManager.default.displayName(atPath: url.path))
            name.lineBreakMode = .byTruncatingTail
            name.translatesAutoresizingMaskIntoConstraints = false
            name.textColor = excluded ? .tertiaryLabelColor : .labelColor

            cell.addSubview(iconView)
            cell.addSubview(name)
            NSLayoutConstraint.activate([
                iconView.leadingAnchor.constraint(equalTo: cell.leadingAnchor, constant: 4),
                iconView.centerYAnchor.constraint(equalTo: cell.centerYAnchor),
                iconView.widthAnchor.constraint(equalToConstant: 22),
                iconView.heightAnchor.constraint(equalToConstant: 22),
                name.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 8),
                name.trailingAnchor.constraint(lessThanOrEqualTo: cell.trailingAnchor, constant: -4),
                name.centerYAnchor.constraint(equalTo: cell.centerYAnchor)
            ])
        }
        return cell
    }

    // MARK: - Tableau : glisser-déposer

    func tableView(_ tableView: NSTableView, pasteboardWriterForRow row: Int) -> NSPasteboardWriting? {
        let item = NSPasteboardItem()
        item.setString(String(row), forType: rowDragType)
        return item
    }

    func tableView(_ tableView: NSTableView,
                   validateDrop info: NSDraggingInfo,
                   proposedRow row: Int,
                   proposedDropOperation dropOperation: NSTableView.DropOperation) -> NSDragOperation {
        if dropOperation == .on {
            tableView.setDropRow(row, dropOperation: .above)
        }
        return .move
    }

    func tableView(_ tableView: NSTableView,
                   acceptDrop info: NSDraggingInfo,
                   row: Int,
                   dropOperation: NSTableView.DropOperation) -> Bool {
        guard let items = info.draggingPasteboard.pasteboardItems,
              let from = items.compactMap({ $0.string(forType: rowDragType) }).compactMap({ Int($0) }).first,
              from >= 0 && from < prefApps.count else { return false }

        var apps = prefApps
        let moved = apps.remove(at: from)
        var destination = row
        if from < row { destination -= 1 }
        destination = max(0, min(destination, apps.count))
        apps.insert(moved, at: destination)

        prefApps = apps
        saveOrder()
        tableView.reloadData()
        tableView.selectRowIndexes(IndexSet(integer: destination), byExtendingSelection: false)
        return true
    }

    // MARK: - Ordre des applications (indépendant du Dock)

    func isFinder(_ url: URL) -> Bool {
        return url.lastPathComponent == "Finder.app"
    }

    func isExcluded(_ url: URL) -> Bool {
        if isFinder(url) && ignoreFinder { return true }
        return excludedAppPaths.contains(url.path)
    }

    func syncFinderExclusion(_ excluded: Bool) {
        guard let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") else { return }
        var paths = excludedAppPaths
        if excluded {
            paths.insert(finderURL.path)
        } else {
            paths.remove(finderURL.path)
        }
        excludedAppPaths = paths
    }

    /// Finder + apps épinglées, dans l'ordre réel du Dock.
    func dockAppsAll() -> [URL] {
        var apps: [URL] = []

        if let finderURL = NSWorkspace.shared.urlForApplication(withBundleIdentifier: "com.apple.finder") {
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

    /// Applique l'ordre personnalisé (s'il existe) par-dessus l'ordre du Dock.
    /// Les apps ajoutées au Dock depuis passent à la fin, celles retirées disparaissent.
    func orderedApps() -> [URL] {
        let all = dockAppsAll()
        let saved = UserDefaults.standard.stringArray(forKey: "customOrder") ?? []
        guard !saved.isEmpty else { return all }

        var remaining = all
        var result: [URL] = []
        for path in saved {
            if let index = remaining.firstIndex(where: { $0.path == path }) {
                result.append(remaining.remove(at: index))
            }
        }
        result.append(contentsOf: remaining)
        return result
    }

    /// Liste finale utilisée par les raccourcis (ordre perso, Finder filtré si besoin).
    func getDockApps() -> [URL] {
        let apps = orderedApps()
        return apps.filter { !isExcluded($0) }
    }

    func getActiveShortcutApps() -> [URL] {
        var apps = getDockApps()
        let dockBundleIDs = Set(apps.compactMap { Bundle(url: $0)?.bundleIdentifier })
        let runningUndocked = NSWorkspace.shared.runningApplications
            .filter { $0.activationPolicy == .regular && $0.bundleIdentifier != Bundle.main.bundleIdentifier }
            .compactMap(\.bundleURL)
            .filter { url in
                guard let bundleID = Bundle(url: url)?.bundleIdentifier else { return false }
                return !dockBundleIDs.contains(bundleID)
            }

        var seenBundleIDs = dockBundleIDs
        for url in runningUndocked where apps.count < 10 {
            guard let bundleID = Bundle(url: url)?.bundleIdentifier,
                  !seenBundleIDs.contains(bundleID) else { continue }
            seenBundleIDs.insert(bundleID)
            apps.append(url)
        }
        return apps
    }

    func saveOrder() {
        UserDefaults.standard.set(prefApps.map { $0.path }, forKey: "customOrder")
    }

    // MARK: - App switching

    func activateApplication(_ url: URL) {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier else {
            NSWorkspace.shared.open(url)
            return
        }

        if let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first {
            if isFinder(url) {
                if finderWindowStateHidden {
                    running.unhide()
                    running.activate(options: [.activateAllWindows])
                    finderWindowStateHidden = false
                    return
                }

                if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
                    if finderHasWindow(for: running) {
                        running.hide()
                        finderWindowStateHidden = true
                    } else {
                        running.activate(options: [.activateAllWindows])
                        NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
                    }
                } else {
                    running.unhide()
                    running.activate(options: [.activateAllWindows])
                    if !finderHasWindow(for: running) {
                        NSWorkspace.shared.open(URL(fileURLWithPath: NSHomeDirectory()))
                    }
                }
            } else if NSWorkspace.shared.frontmostApplication?.bundleIdentifier == bundleID {
                running.hide()
            } else {
                running.activate(options: [])
            }
            return
        }

        if isFinder(url) {
            finderWindowStateHidden = false
            NSWorkspace.shared.open(url)
        } else {
            NSWorkspace.shared.open(url)
        }
    }

    func finderHasWindow(for running: NSRunningApplication) -> Bool {
        guard let windowInfo = CGWindowListCopyWindowInfo(
            [.optionAll],
            kCGNullWindowID
        ) as? [[String: Any]] else {
            return false
        }

        return windowInfo.contains { entry in
            guard let pid = entry[kCGWindowOwnerPID as String] as? NSNumber,
                  let layer = entry[kCGWindowLayer as String] as? NSNumber else {
                return false
            }
            return pid.int32Value == running.processIdentifier && layer.intValue == 0
        }
    }


    func quitApplication(_ url: URL) {
        guard let bundleID = Bundle(url: url)?.bundleIdentifier,
              let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID).first else { return }
        running.terminate()
    }

    // MARK: - Hold-to-peek HUD

    func installModifierMonitors() {
        globalFlagsMonitor = NSEvent.addGlobalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.modifierFlagsChanged(event.modifierFlags)
        }
        localFlagsMonitor = NSEvent.addLocalMonitorForEvents(matching: .flagsChanged) { [weak self] event in
            self?.modifierFlagsChanged(event.modifierFlags)
            return event
        }
    }

    func configuredModifierFlags() -> NSEvent.ModifierFlags {
        let carbon = modifierOptions[selectedModifierIndex].flags
        var result: NSEvent.ModifierFlags = []
        if carbon & UInt32(cmdKey) != 0 { result.insert(.command) }
        if carbon & UInt32(optionKey) != 0 { result.insert(.option) }
        if carbon & UInt32(controlKey) != 0 { result.insert(.control) }
        if carbon & UInt32(shiftKey) != 0 { result.insert(.shift) }
        return result
    }

    func modifierFlagsChanged(_ flags: NSEvent.ModifierFlags) {
        let relevant: NSEvent.ModifierFlags = [.command, .option, .control, .shift]
        let current = flags.intersection(relevant)
        let configured = configuredModifierFlags()
        if current != configured {
            cancelPeek()
            return
        }

        peekTimer?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.showPeekHUD()
        }
        peekTimer = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.45, execute: work)
    }

    func cancelPeek() {
        peekTimer?.cancel()
        peekTimer = nil
        peekPanel?.orderOut(nil)
    }

    func showPeekHUD() {
        let apps: [(url: URL, badge: String)] = getActiveShortcutApps().enumerated().map { index, url in
            (url, index == 9 ? "0" : "\(index + 1)")
        }

        guard !apps.isEmpty else { return }
        let itemSize: CGFloat = 80
        let size = NSSize(width: itemSize * CGFloat(apps.count), height: 92)

        let panel: NSPanel
        if let existing = peekPanel {
            panel = existing
        } else {
            panel = NSPanel(contentRect: .zero,
                            styleMask: [.borderless, .nonactivatingPanel],
                            backing: .buffered,
                            defer: false)
            panel.level = .floating
            panel.isOpaque = false
            panel.backgroundColor = .clear
            panel.hasShadow = true
            panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
            peekPanel = panel
        }

        let visual: NSView
        if let glassType = NSClassFromString("NSGlassEffectView") as? NSView.Type {
            let glass = glassType.init(frame: NSRect(origin: .zero, size: size))
            if glass.responds(to: NSSelectorFromString("setCornerRadius:")) {
                glass.setValue(22, forKey: "cornerRadius")
            }
            if glass.responds(to: NSSelectorFromString("setTintColor:")) {
                glass.setValue(NSColor.white.withAlphaComponent(0.12), forKey: "tintColor")
            }
            glass.wantsLayer = true
            glass.layer?.cornerRadius = 22
            glass.layer?.masksToBounds = true
            glass.layer?.borderWidth = 0.6
            glass.layer?.borderColor = NSColor.white.withAlphaComponent(0.38).cgColor
            visual = glass
        } else {
            let effect = NSVisualEffectView(frame: NSRect(origin: .zero, size: size))
            effect.material = .hudWindow
            effect.blendingMode = .behindWindow
            effect.state = .followsWindowActiveState
            effect.wantsLayer = true
            effect.layer?.cornerRadius = 22
            effect.layer?.masksToBounds = true
            effect.layer?.borderWidth = 0.6
            effect.layer?.borderColor = NSColor.white.withAlphaComponent(0.38).cgColor
            visual = effect
        }

        var x: CGFloat = 0
        for app in apps {
            let container = NSView(frame: NSRect(x: x, y: 0, width: itemSize, height: 92))
            container.wantsLayer = true
            let icon = NSImageView(frame: NSRect(x: 16, y: 28, width: 48, height: 48))
            icon.image = NSWorkspace.shared.icon(forFile: app.url.path)
            icon.imageScaling = .scaleAxesIndependently
            icon.imageAlignment = .alignCenter

            let badge = CATextLayer()
            badge.string = app.badge
            badge.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
            badge.fontSize = 12
            badge.foregroundColor = NSColor.labelColor.cgColor
            badge.alignmentMode = .center
            badge.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
            badge.frame = NSRect(x: 8, y: 4, width: itemSize - 16, height: 18)
            badge.truncationMode = .none
            badge.shadowColor = NSColor.black.withAlphaComponent(0.35).cgColor
            badge.shadowOpacity = 0.7
            badge.shadowRadius = 1
            badge.shadowOffset = CGSize(width: 0, height: -1)

            container.addSubview(icon)
            container.layer?.addSublayer(badge)
            visual.addSubview(container)
            x += itemSize
        }

        panel.contentView = visual
        panel.setContentSize(size)
        if let screen = NSScreen.main {
            let origin = NSPoint(x: screen.visibleFrame.midX - size.width / 2,
                                 y: screen.visibleFrame.minY + 24)
            panel.setFrameOrigin(origin)
        }
        panel.orderFrontRegardless()
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
            let apps = mySelf.getActiveShortcutApps()

            if index > 0 && index <= apps.count {
                mySelf.cancelPeek()
                mySelf.activateApplication(apps[index - 1])
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
