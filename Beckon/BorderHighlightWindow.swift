import AppKit
import SwiftUI

// MARK: - Color helpers

enum BorderHighlightDefaults {
    static let colorHex = "#E2E2E3"
    static let width: CGFloat = 2
}

enum BorderAutoColorResolver {
    private static let lightAppearanceBorderHex = "#2C2C2E"
    private static let darkAppearanceBorderHex = "#E2E2E3"

    @MainActor
    static func color(for appearance: NSAppearance?) -> NSColor {
        let match = appearance?.bestMatch(from: [.darkAqua, .aqua])
        if match == .darkAqua {
            return NSColor(hex: darkAppearanceBorderHex) ?? .white
        }
        return NSColor(hex: lightAppearanceBorderHex) ?? .black
    }
}

extension NSColor {
    /// Parses a canonical 6-digit hex color string (#RRGGBB or RRGGBB).
    convenience init?(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        let rgb = cleaned.hasPrefix("#") ? String(cleaned.dropFirst()) : cleaned
        guard rgb.count == 6 else {
            return nil
        }
        var value: UInt64 = 0
        guard Scanner(string: rgb).scanHexInt64(&value) else {
            return nil
        }
        let r = CGFloat((value >> 16) & 0xFF) / 255
        let g = CGFloat((value >> 8) & 0xFF) / 255
        let b = CGFloat(value & 0xFF) / 255
        self.init(srgbRed: r, green: g, blue: b, alpha: 1)
    }
}

extension Color {
    /// Parses canonical #RRGGBB and falls back to the app default on invalid input.
    init(hex: String) {
        let ns = NSColor(hex: hex) ?? NSColor(hex: BorderHighlightDefaults.colorHex) ?? .systemRed
        self.init(nsColor: ns)
    }

    /// Serializes the color to a 6-digit uppercase hex string like "#FF453A".
    func toHex() -> String {
        let ns = NSColor(self).usingColorSpace(.sRGB) ?? .red
        let r = Int((ns.redComponent * 255).rounded())
        let g = Int((ns.greenComponent * 255).rounded())
        let b = Int((ns.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}

// MARK: - Border view

private final class BorderView: NSView {
    var strokeColor: NSColor = NSColor(hex: BorderHighlightDefaults.colorHex) ?? .systemRed
    var strokeWidth: CGFloat = BorderHighlightDefaults.width
    var cornerRadius: CGFloat = 8

    override func draw(_ dirtyRect: NSRect) {
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        ctx.setShouldAntialias(true)
        ctx.setStrokeColor(strokeColor.cgColor)
        ctx.setLineWidth(strokeWidth)
        ctx.setLineJoin(.round)
        ctx.setLineCap(.round)
        // Inset by half stroke width so the entire stroke falls inside the view bounds.
        let rect = bounds.insetBy(dx: strokeWidth / 2, dy: strokeWidth / 2)
        let path = CGPath(
            roundedRect: rect,
            cornerWidth: cornerRadius,
            cornerHeight: cornerRadius,
            transform: nil
        )
        ctx.addPath(path)
        ctx.strokePath()
    }
}

// MARK: - Overlay panel

/// A transparent floating panel that draws a colored border around the focused window.
/// The panel sits at `.floating` level and ignores all mouse events.
final class BorderHighlightWindow: NSPanel {
    static let shared = BorderHighlightWindow()

    var borderColor: NSColor = NSColor(hex: BorderHighlightDefaults.colorHex) ?? .systemRed {
        didSet { borderView.strokeColor = borderColor }
    }
    var borderWidth: CGFloat = BorderHighlightDefaults.width {
        didSet { borderView.strokeWidth = borderWidth }
    }

    private let borderView = BorderView()

    private init() {
        super.init(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        isOpaque = false
        backgroundColor = .clear
        level = .floating
        ignoresMouseEvents = true
        // Follow active Space; never appears in window switcher.
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        isReleasedWhenClosed = false
        contentView = borderView
    }

    /// Converts a CGRect in CG screen coordinates (origin top-left) to AppKit
    /// screen coordinates (origin bottom-left of the primary screen).
    static func appKitFrame(forCGFrame cgFrame: CGRect, screenHeight: CGFloat) -> CGRect {
        CGRect(
            x: cgFrame.origin.x,
            y: screenHeight - cgFrame.origin.y - cgFrame.height,
            width: cgFrame.width,
            height: cgFrame.height
        )
    }

    /// Positions the panel over `cgFrame` (CG screen coordinates) and makes it visible.
    func show(forCGFrame cgFrame: CGRect, screenHeight: CGFloat) {
        borderView.strokeColor = borderColor
        borderView.strokeWidth = borderWidth
        let frame = BorderHighlightWindow.appKitFrame(forCGFrame: cgFrame, screenHeight: screenHeight)
        setFrame(frame, display: false)
        borderView.needsDisplay = true
        if !isVisible {
            orderFront(nil)
        }
    }

    func hide() {
        orderOut(nil)
    }
}
