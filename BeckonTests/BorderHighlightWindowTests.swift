import XCTest
import SwiftUI
@testable import Beckon

@MainActor
final class BorderHighlightWindowTests: XCTestCase {

    // MARK: - Coordinate conversion

    func testAppKitFrameMidScreen() {
        // CG: x=100, y=50, w=800, h=600 on 1200-pt tall screen
        // AppKit y = 1200 - 50 - 600 = 550
        let result = BorderHighlightWindow.appKitFrame(
            forCGFrame: CGRect(x: 100, y: 50, width: 800, height: 600),
            screenHeight: 1200
        )
        XCTAssertEqual(result, CGRect(x: 100, y: 550, width: 800, height: 600))
    }

    func testAppKitFrameAtScreenTop() {
        // Window at CG y=0 should appear at the top in AppKit: AppKit y = screenH - h
        let result = BorderHighlightWindow.appKitFrame(
            forCGFrame: CGRect(x: 0, y: 0, width: 1920, height: 40),
            screenHeight: 1080
        )
        XCTAssertEqual(result, CGRect(x: 0, y: 1040, width: 1920, height: 40))
    }

    func testAppKitFrameAtScreenBottom() {
        // Window flush at the bottom in AppKit: AppKit y = 0
        let result = BorderHighlightWindow.appKitFrame(
            forCGFrame: CGRect(x: 0, y: 900, width: 1920, height: 100),
            screenHeight: 1000
        )
        XCTAssertEqual(result, CGRect(x: 0, y: 0, width: 1920, height: 100))
    }

    func testAppKitFramePreservesWidthAndHeight() {
        let input = CGRect(x: 200, y: 300, width: 640, height: 480)
        let result = BorderHighlightWindow.appKitFrame(forCGFrame: input, screenHeight: 900)
        XCTAssertEqual(result.width, 640)
        XCTAssertEqual(result.height, 480)
    }

    // MARK: - NSColor hex parsing

    func testNSColorHexParsesRed() {
        let color = NSColor(hex: "#FF0000")
        XCTAssertNotNil(color)
        let srgb = color?.usingColorSpace(.sRGB)
        XCTAssertEqual(srgb?.redComponent ?? 0, 1.0, accuracy: 0.01)
        XCTAssertEqual(srgb?.greenComponent ?? 0, 0.0, accuracy: 0.01)
        XCTAssertEqual(srgb?.blueComponent ?? 0, 0.0, accuracy: 0.01)
    }

    func testNSColorHexParsesWithoutHash() {
        let color = NSColor(hex: "00FF00")
        XCTAssertNotNil(color)
        let srgb = color?.usingColorSpace(.sRGB)
        XCTAssertEqual(srgb?.greenComponent ?? 0, 1.0, accuracy: 0.01)
    }

    func testNSColorHexRejectsNonCanonical0xStyle() {
        XCTAssertNil(NSColor(hex: "0xffe2e2e3"))
    }

    func testNSColorHexTooShortReturnsNil() {
        XCTAssertNil(NSColor(hex: "#FFF"))
    }

    func testNSColorHexInvalidCharsReturnsNil() {
        XCTAssertNil(NSColor(hex: "#ZZZZZZ"))
    }

    // MARK: - Color hex round-trip

    func testColorHexRoundTrip() {
        let original = "#3A7FFF"
        let color = Color(hex: original)
        let back = color.toHex()
        XCTAssertEqual(back, original)
    }

    func testColorHexRoundTripBlack() {
        XCTAssertEqual(Color(hex: "#000000").toHex(), "#000000")
    }

    func testColorHexRoundTripWhite() {
        XCTAssertEqual(Color(hex: "#FFFFFF").toHex(), "#FFFFFF")
    }

    // MARK: - Auto color mode

    func testAutoColorUsesDarkBorderOnLightAppearance() {
        let color = BorderAutoColorResolver.color(for: NSAppearance(named: .aqua))
        XCTAssertEqual(hex(color), "#2C2C2E")
    }

    func testAutoColorUsesLightBorderOnDarkAppearance() {
        let color = BorderAutoColorResolver.color(for: NSAppearance(named: .darkAqua))
        XCTAssertEqual(hex(color), "#E2E2E3")
    }

    func testAutoColorDefaultsToLightAppearanceBehaviorWhenAppearanceIsNil() {
        let color = BorderAutoColorResolver.color(for: nil)
        XCTAssertEqual(hex(color), "#2C2C2E")
    }

    private func hex(_ color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int((srgb.redComponent * 255).rounded())
        let g = Int((srgb.greenComponent * 255).rounded())
        let b = Int((srgb.blueComponent * 255).rounded())
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
