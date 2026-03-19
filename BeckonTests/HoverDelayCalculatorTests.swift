import XCTest
@testable import Beckon

final class HoverDelayCalculatorTests: XCTestCase {
    func testReturnsBaseDelayWhenNoPreviousEventTimestamp() {
        let delay = HoverDelayCalculator.effectiveDelayMs(
            baseDelayMs: 25,
            lastEventTimestamp: 0,
            currentTimestamp: 100,
            deltaX: 10,
            deltaY: 0,
            velocitySensitivity: 0.08
        )

        XCTAssertEqual(delay, 25, accuracy: 0.0001)
    }

    func testReturnsBaseDelayWhenTimeDeltaIsNonPositive() {
        let delay = HoverDelayCalculator.effectiveDelayMs(
            baseDelayMs: 25,
            lastEventTimestamp: 5,
            currentTimestamp: 5,
            deltaX: 10,
            deltaY: 10,
            velocitySensitivity: 0.08
        )

        XCTAssertEqual(delay, 25, accuracy: 0.0001)
    }

    func testScalesDelayWithPointerSpeed() {
        let delay = HoverDelayCalculator.effectiveDelayMs(
            baseDelayMs: 25,
            lastEventTimestamp: 1.0,
            currentTimestamp: 1.1,
            deltaX: 100,
            deltaY: 0,
            velocitySensitivity: 0.08
        )

        XCTAssertEqual(delay, 105, accuracy: 0.001)
    }

    func testNegativeSensitivityIsClampedToZero() {
        let delay = HoverDelayCalculator.effectiveDelayMs(
            baseDelayMs: 25,
            lastEventTimestamp: 1.0,
            currentTimestamp: 1.1,
            deltaX: 100,
            deltaY: 0,
            velocitySensitivity: -1.0
        )

        XCTAssertEqual(delay, 25, accuracy: 0.0001)
    }

    func testDelayIsCappedAtMaximum() {
        let delay = HoverDelayCalculator.effectiveDelayMs(
            baseDelayMs: 25,
            lastEventTimestamp: 1.0,
            currentTimestamp: 1.01,
            deltaX: 1000,
            deltaY: 0,
            velocitySensitivity: 0.2,
            maxDelayMs: 500
        )

        XCTAssertEqual(delay, 500, accuracy: 0.0001)
    }
}
