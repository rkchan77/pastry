import AppKit
import Carbon
import ServiceManagement

final class AppDelegate: NSObject, NSApplicationDelegate {
    private let store = ClipboardStore()
    private var panel: PanelController!
    private var hotKey: HotKey?
    private var statusItem: NSStatusItem!
    private var loginItem: NSMenuItem!

    // Change the shortcut here. Default: Cmd+Option+V.
    // (Cmd+Shift+V would be UInt32(cmdKey | shiftKey).)
    private let hotKeyCode = UInt32(kVK_ANSI_V)
    private let hotKeyModifiers = UInt32(cmdKey | optionKey)

    func applicationDidFinishLaunching(_ notification: Notification) {
        Paster.ensureAccessibility()
        store.start()
        panel = PanelController(store: store)
        hotKey = HotKey(keyCode: hotKeyCode, modifiers: hotKeyModifiers) { [weak self] in
            self?.panel.toggle()
        }
        setUpMenuBar()
    }

    private func setUpMenuBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = PancakeGlyph.image(points: 18)

        let menu = NSMenu()
        menu.addItem(withTitle: "Show Pastry (⌘⌥V)", action: #selector(showPanel), keyEquivalent: "")
        menu.addItem(withTitle: "Clear History", action: #selector(clearHistory), keyEquivalent: "")
        menu.addItem(.separator())
        loginItem = menu.addItem(withTitle: "Open at Login", action: #selector(toggleLogin), keyEquivalent: "")
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
        menu.addItem(.separator())
        menu.addItem(withTitle: "Quit Pastry", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        for item in menu.items where item.action != #selector(NSApplication.terminate(_:)) {
            item.target = self
        }
        statusItem.menu = menu
    }

    @objc private func showPanel() { panel.show() }
    @objc private func clearHistory() { store.clear() }

    @objc private func toggleLogin() {
        do {
            if SMAppService.mainApp.status == .enabled {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
        } catch {
            NSLog("Pastry login item error: \(error)")
        }
        loginItem.state = SMAppService.mainApp.status == .enabled ? .on : .off
    }
}
