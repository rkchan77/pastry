import AppKit

/// The pancake-stack glyph (Resources/PancakeTemplate.png) as a template image,
/// so macOS tints it to match the menu bar and the panel automatically.
enum PancakeGlyph {
    static func image(points: CGFloat) -> NSImage {
        if let url = Bundle.main.url(forResource: "PancakeTemplate", withExtension: "png"),
           let source = NSImage(contentsOf: url),
           let copy = source.copy() as? NSImage {
            copy.size = NSSize(width: points, height: points)
            copy.isTemplate = true
            return copy
        }
        // Fallback when running outside the .app bundle (e.g. `swift run`).
        let fallback = NSImage(systemSymbolName: "square.stack.fill", accessibilityDescription: "Pastry")!
        fallback.isTemplate = true
        return fallback
    }
}
