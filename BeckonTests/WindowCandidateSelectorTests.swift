import CoreGraphics
import XCTest
@testable import Beckon

final class WindowCandidateSelectorTests: XCTestCase {
    private func makeWindowInfo(
        layer: Int = 0,
        bounds: CGRect,
        windowNumber: Int,
        pid: pid_t
    ) -> [String: Any] {
        let boundsDict = bounds.dictionaryRepresentation as NSDictionary as! [String: Any]
        return [
            kCGWindowLayer as String: layer,
            kCGWindowBounds as String: boundsDict,
            kCGWindowNumber as String: windowNumber,
            kCGWindowOwnerPID as String: pid,
        ]
    }

    func testReturnsOnlyLayerZeroContainingPointAndNotCurrentProcess() {
        let point = CGPoint(x: 50, y: 50)
        let currentPID: pid_t = 999

        let list: [[String: Any]] = [
            makeWindowInfo(layer: 1, bounds: CGRect(x: 300, y: 300, width: 50, height: 50), windowNumber: 1, pid: 100),
            makeWindowInfo(layer: 0, bounds: CGRect(x: 300, y: 300, width: 50, height: 50), windowNumber: 2, pid: 101),
            makeWindowInfo(layer: 0, bounds: CGRect(x: 0, y: 0, width: 200, height: 200), windowNumber: 3, pid: currentPID),
            makeWindowInfo(layer: 0, bounds: CGRect(x: 0, y: 0, width: 200, height: 200), windowNumber: 4, pid: 102),
        ]

        let candidates = WindowCandidateSelector.candidates(
            under: point,
            from: list,
            excludingProcessID: currentPID
        )

        XCTAssertEqual(candidates, [WindowCandidate(processID: 102, windowNumber: 4)])
    }

    func testPreservesInputOrderForMultipleMatches() {
        let point = CGPoint(x: 10, y: 10)

        let list: [[String: Any]] = [
            makeWindowInfo(bounds: CGRect(x: 0, y: 0, width: 100, height: 100), windowNumber: 10, pid: 200),
            makeWindowInfo(bounds: CGRect(x: 0, y: 0, width: 100, height: 100), windowNumber: 11, pid: 201),
            makeWindowInfo(bounds: CGRect(x: 20, y: 20, width: 100, height: 100), windowNumber: 12, pid: 202),
        ]

        let candidates = WindowCandidateSelector.candidates(
            under: point,
            from: list,
            excludingProcessID: 0
        )

        XCTAssertEqual(
            candidates.map(\.windowNumber),
            [10, 11]
        )
    }

    func testSkipsEntriesWithMissingFields() {
        let point = CGPoint(x: 10, y: 10)

        let incomplete: [String: Any] = [
            kCGWindowLayer as String: 0,
            kCGWindowNumber as String: 77,
        ]

        let valid = makeWindowInfo(
            bounds: CGRect(x: 0, y: 0, width: 30, height: 30),
            windowNumber: 88,
            pid: 555
        )

        let candidates = WindowCandidateSelector.candidates(
            under: point,
            from: [incomplete, valid],
            excludingProcessID: 0
        )

        XCTAssertEqual(candidates, [WindowCandidate(processID: 555, windowNumber: 88)])
    }

    func testReturnsNoCandidatesWhenTopmostLayerIsNotZero() {
        let point = CGPoint(x: 40, y: 40)

        let list: [[String: Any]] = [
            makeWindowInfo(layer: 25, bounds: CGRect(x: 0, y: 0, width: 100, height: 100), windowNumber: 1, pid: 100),
            makeWindowInfo(layer: 0, bounds: CGRect(x: 0, y: 0, width: 100, height: 100), windowNumber: 2, pid: 101),
        ]

        let candidates = WindowCandidateSelector.candidates(
            under: point,
            from: list,
            excludingProcessID: 0
        )

        XCTAssertTrue(candidates.isEmpty)
    }

    func testIgnoresTopmostNonZeroLayerFromCurrentProcess() {
        let point = CGPoint(x: 40, y: 40)
        let currentPID: pid_t = 999

        let list: [[String: Any]] = [
            makeWindowInfo(layer: 25, bounds: CGRect(x: 0, y: 0, width: 100, height: 100), windowNumber: 1, pid: currentPID),
            makeWindowInfo(layer: 0, bounds: CGRect(x: 0, y: 0, width: 100, height: 100), windowNumber: 2, pid: 101),
        ]

        let candidates = WindowCandidateSelector.candidates(
            under: point,
            from: list,
            excludingProcessID: currentPID
        )

        XCTAssertEqual(candidates, [WindowCandidate(processID: 101, windowNumber: 2)])
    }
}
