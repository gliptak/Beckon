import ApplicationServices
import CoreGraphics
import XCTest
@testable import Beckon

final class WindowFinderTests: XCTestCase {

    // MARK: - AXWindowFrameDecoder

    private func makeAXPoint(_ point: CGPoint) -> AXValue {
        var p = point
        return AXValueCreate(.cgPoint, &p)!
    }

    private func makeAXSize(_ size: CGSize) -> AXValue {
        var s = size
        return AXValueCreate(.cgSize, &s)!
    }

    func testDecodeValidPositionAndSize() {
        let posVal = makeAXPoint(CGPoint(x: 10, y: 20))
        let sizeVal = makeAXSize(CGSize(width: 800, height: 600))

        let frame = AXWindowFrameDecoder.frame(positionValue: posVal, sizeValue: sizeVal)

        XCTAssertEqual(frame, CGRect(x: 10, y: 20, width: 800, height: 600))
    }

    func testDecodeZeroOriginAndSize() {
        let posVal = makeAXPoint(.zero)
        let sizeVal = makeAXSize(.zero)

        let frame = AXWindowFrameDecoder.frame(positionValue: posVal, sizeValue: sizeVal)

        XCTAssertEqual(frame, .zero)
    }

    func testDecodeRejectsWrongAXValueTypeForSize() {
        // Passing a cgPoint AXValue where a cgSize is expected should return nil.
        let posVal = makeAXPoint(CGPoint(x: 0, y: 0))
        let wrongTypeForSize = makeAXPoint(CGPoint(x: 100, y: 200)) // cgPoint, not cgSize

        let frame = AXWindowFrameDecoder.frame(positionValue: posVal, sizeValue: wrongTypeForSize)

        XCTAssertNil(frame)
    }

    func testDecodeRejectsWrongAXValueTypeForPosition() {
        // Passing a cgSize AXValue where a cgPoint is expected should return nil.
        let wrongTypeForPos = makeAXSize(CGSize(width: 100, height: 200)) // cgSize, not cgPoint
        let sizeVal = makeAXSize(CGSize(width: 800, height: 600))

        let frame = AXWindowFrameDecoder.frame(positionValue: wrongTypeForPos, sizeValue: sizeVal)

        XCTAssertNil(frame)
    }

    func testDecodeRejectsNonAXValueCFType() {
        // Passing a plain CFString (not an AXValue at all) should return nil.
        let notAnAXValue: CFTypeRef = "not an AXValue" as CFString
        let sizeVal = makeAXSize(CGSize(width: 800, height: 600))

        let frame = AXWindowFrameDecoder.frame(positionValue: notAnAXValue, sizeValue: sizeVal)

        XCTAssertNil(frame)
    }
}
