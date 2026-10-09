import AppKit
import SwiftUI

/// Borderless floating panel that can take keyboard focus without
/// stealing "frontmost app" status, so Cmd+V lands in the app you were using.
final class ClipPanel: NSPanel {
    init() {
        super.init(contentRect: .zero,
                   styleMask: [.nonactivatingPanel, .borderless],
                   backing: .buffered, defer: false)
        isFloatingPanel = true
        level = .popUpMenu
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        hidesOnDeactivate = false
    }
    override var canBecomeKey: Bool { true }
}

final class PanelController {
    private let store: ClipboardStore
    private let state = PanelState()
    private let panel = ClipPanel()
    private var clickMonitor: Any?
    private var keyMonitor: Any?
    private let size = NSSize(width: 340, height: 420)

    init(store: ClipboardStore) {
        self.store = store

        let blur = NSVisualEffectView()
        blur.material = .popover
        blur.state = .active
        // Clip the blur (and therefore the window shadow) to rounded corners,
        // so no square outline shows around the panel.
        blur.maskImage = Self.roundedMask(radius: 12)

        let host = NSHostingView(rootView: ClipListView(store: store, state: state) { [weak self] item in
            self?.pick(item)
        })
        host.translatesAutoresizingMaskIntoConstraints = false
        blur.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: blur.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: blur.trailingAnchor),
            host.topAnchor.constraint(equalTo: blur.topAnchor),
            host.bottomAnchor.constraint(equalTo: blur.bottomAnchor),
        ])
        panel.contentView = blur
    }

    /// Stretchable rounded-rect image used as the blur view's mask.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    func toggle() { panel.isVisible ? hide() : show() }

    func show() {
        // Open at the mouse, clamped so it stays on screen.
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        var origin = NSPoint(x: mouse.x, y: mouse.y - size.height)
        if let vf = screen?.visibleFrame {
            origin.x = min(max(origin.x, vf.minX + 8), vf.maxX - size.width - 8)
            origin.y = min(max(origin.y, vf.minY + 8), vf.maxY - size.height - 8)
        }
        state.selected = 0
        state.lastMouse = mouse
        panel.setFrame(NSRect(origin: origin, size: size), display: true)
        panel.makeKeyAndOrderFront(nil)
        panel.invalidateShadow()   // recompute the shadow from the rounded shape

        // Any click in another app closes it.
        clickMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown, .otherMouseDown]
        ) { [weak self] _ in self?.hide() }

        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self, self.panel.isKeyWindow else { return event }
            return self.handleKey(event) ? nil : event
        }
    }

    func hide() {
        panel.orderOut(nil)
        if let m = clickMonitor { NSEvent.removeMonitor(m); clickMonitor = nil }
        if let m = keyMonitor { NSEvent.removeMonitor(m); keyMonitor = nil }
    }

    private func pick(_ item: ClipItem) {
        hide()
        store.restore(item)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { Paster.paste() }
    }

    /// Keyboard: ↑/↓ move, Return pastes, 1–9 pastes that item, Delete removes, Esc closes.
    private func handleKey(_ event: NSEvent) -> Bool {
        let items = store.items
        switch event.keyCode {
        case 53: hide(); return true                                        // Esc
        case 125: state.selected = min(state.selected + 1, max(items.count - 1, 0)); return true
        case 126: state.selected = max(state.selected - 1, 0); return true
        case 36, 76:                                                        // Return / Enter
            if items.indices.contains(state.selected) { pick(items[state.selected]) }
            return true
        case 51, 117:                                                       // Delete
            if items.indices.contains(state.selected) {
                store.remove(items[state.selected])
                state.selected = min(state.selected, max(store.items.count - 1, 0))
            }
            return true
        default:
            if let c = event.charactersIgnoringModifiers, let n = Int(c), (1...9).contains(n),
               items.indices.contains(n - 1) {
                pick(items[n - 1]); return true
            }
            return false
        }
    }
}

enum Paster {
    /// Sends Cmd+V to the frontmost app. Requires Accessibility permission.
    static func paste() {
        let src = CGEventSource(stateID: .combinedSessionState)
        let vKey: CGKeyCode = 9
        let down = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: true)
        let up = CGEvent(keyboardEventSource: src, virtualKey: vKey, keyDown: false)
        down?.flags = .maskCommand
        up?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        up?.post(tap: .cghidEventTap)
    }

    static func ensureAccessibility() {
        let key = kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String
        _ = AXIsProcessTrustedWithOptions([key: true] as CFDictionary)
    }
}
