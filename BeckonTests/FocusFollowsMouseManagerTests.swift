import ApplicationServices
import CoreGraphics
import XCTest
@testable import Beckon

final class FocusFollowsMouseManagerTests: XCTestCase {
    private final class StubFinder: WindowFinding {
        var debugLastLookup: String = "stub"
        var matches: [WindowMatch?] = []

        func windowUnderMouse(at mouseLocation: CGPoint) -> WindowMatch? {
            guard !matches.isEmpty else {
                return nil
            }
            return matches.removeFirst()
        }
    }

    private final class RecordingScheduler {
        private(set) var scheduledItems: [DispatchWorkItem] = []

        func schedule(delaySeconds: Double, workItem: DispatchWorkItem) {
            scheduledItems.append(workItem)
        }

        func runItem(at index: Int) {
            let item = scheduledItems[index]
            guard !item.isCancelled else {
                return
            }
            item.perform()
        }
    }

    private func makeMatch(windowNumber: Int, pid: pid_t = 1001) -> WindowMatch {
        WindowMatch(
            processID: pid,
            windowElement: AXUIElementCreateSystemWide(),
            windowNumber: windowNumber
        )
    }

    func testNewScheduleCancelsPreviousPendingWorkItem() {
        let finder = StubFinder()
        finder.matches = [makeMatch(windowNumber: 1), makeMatch(windowNumber: 2)]

        let scheduler = RecordingScheduler()
        let manager = FocusFollowsMouseManager(
            finder: finder,
            isProcessTrusted: { true },
            mouseLocationProvider: { .zero },
            primaryScreenHeightProvider: { 100 },
            scheduleWorkItem: scheduler.schedule(delaySeconds:workItem:),
            nowProvider: { Date(timeIntervalSince1970: 0) },
            focusExecutor: { _, _ in }
        )

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        manager.scheduleFocusCheck(timestamp: 2.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)

        XCTAssertEqual(scheduler.scheduledItems.count, 2)
        XCTAssertTrue(scheduler.scheduledItems[0].isCancelled)
        XCTAssertFalse(scheduler.scheduledItems[1].isCancelled)
    }

    func testDuplicateWindowDoesNotReapplyFocus() {
        let finder = StubFinder()
        finder.matches = [makeMatch(windowNumber: 7), makeMatch(windowNumber: 7)]

        let scheduler = RecordingScheduler()
        var focusedWindowNumbers: [Int] = []

        let manager = FocusFollowsMouseManager(
            finder: finder,
            isProcessTrusted: { true },
            mouseLocationProvider: { .zero },
            primaryScreenHeightProvider: { 100 },
            scheduleWorkItem: scheduler.schedule(delaySeconds:workItem:),
            nowProvider: { Date(timeIntervalSince1970: 0) },
            focusExecutor: { match, _ in
                focusedWindowNumbers.append(match.windowNumber)
            }
        )

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 0)

        manager.scheduleFocusCheck(timestamp: 2.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 1)

        XCTAssertEqual(focusedWindowNumbers, [7])
    }

    func testRaiseFlagIsForwardedToFocusExecutor() {
        let finder = StubFinder()
        finder.matches = [makeMatch(windowNumber: 11)]

        let scheduler = RecordingScheduler()
        var recordedRaiseValues: [Bool] = []

        let manager = FocusFollowsMouseManager(
            finder: finder,
            isProcessTrusted: { true },
            mouseLocationProvider: { .zero },
            primaryScreenHeightProvider: { 100 },
            scheduleWorkItem: scheduler.schedule(delaySeconds:workItem:),
            nowProvider: { Date(timeIntervalSince1970: 0) },
            focusExecutor: { _, raise in
                recordedRaiseValues.append(raise)
            }
        )

        manager.raiseOnFocus = false
        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 0)

        XCTAssertEqual(recordedRaiseValues, [false])
    }

    func testUntrustedPathSkipsSchedulingAndSetsDebugInfo() {
        let finder = StubFinder()
        finder.matches = [makeMatch(windowNumber: 1)]

        let scheduler = RecordingScheduler()
        let manager = FocusFollowsMouseManager(
            finder: finder,
            isProcessTrusted: { false },
            mouseLocationProvider: { .zero },
            primaryScreenHeightProvider: { 100 },
            scheduleWorkItem: scheduler.schedule(delaySeconds:workItem:),
            nowProvider: { Date(timeIntervalSince1970: 0) },
            focusExecutor: { _, _ in }
        )

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: false)

        XCTAssertEqual(manager.debugLastWindowInfo, "AX permission denied")
        XCTAssertEqual(scheduler.scheduledItems.count, 0)
    }

    func testNoWindowMatchUsesFinderDebugInfoAndSkipsScheduling() {
        let finder = StubFinder()
        finder.debugLastLookup = "No window at point"
        finder.matches = [nil]

        let scheduler = RecordingScheduler()
        let manager = FocusFollowsMouseManager(
            finder: finder,
            isProcessTrusted: { true },
            mouseLocationProvider: { .zero },
            primaryScreenHeightProvider: { 100 },
            scheduleWorkItem: scheduler.schedule(delaySeconds:workItem:),
            nowProvider: { Date(timeIntervalSince1970: 0) },
            focusExecutor: { _, _ in }
        )

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)

        XCTAssertEqual(manager.debugLastWindowInfo, "No window at point")
        XCTAssertEqual(scheduler.scheduledItems.count, 0)
    }

    func testMatchedWindowUpdatesDebugInfoAndEventTime() {
        let finder = StubFinder()
        finder.matches = [makeMatch(windowNumber: 42, pid: 2002)]

        let scheduler = RecordingScheduler()
        let manager = FocusFollowsMouseManager(
            finder: finder,
            isProcessTrusted: { true },
            mouseLocationProvider: { .zero },
            primaryScreenHeightProvider: { 100 },
            scheduleWorkItem: scheduler.schedule(delaySeconds:workItem:),
            nowProvider: { Date(timeIntervalSince1970: 0) },
            focusExecutor: { _, _ in }
        )

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)

        XCTAssertEqual(manager.debugLastWindowInfo, "Window #42 (PID 2002)")
        XCTAssertNotEqual(manager.debugLastEventTime, "—")
        XCTAssertEqual(scheduler.scheduledItems.count, 1)
    }

    func testDisableCancelsPendingWorkItem() {
        let finder = StubFinder()
        finder.matches = [makeMatch(windowNumber: 9)]

        let scheduler = RecordingScheduler()
        let manager = FocusFollowsMouseManager(
            finder: finder,
            isProcessTrusted: { true },
            mouseLocationProvider: { .zero },
            primaryScreenHeightProvider: { 100 },
            scheduleWorkItem: scheduler.schedule(delaySeconds:workItem:),
            nowProvider: { Date(timeIntervalSince1970: 0) },
            focusExecutor: { _, _ in }
        )

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        XCTAssertEqual(scheduler.scheduledItems.count, 1)
        XCTAssertFalse(scheduler.scheduledItems[0].isCancelled)

        manager.setEnabled(false)

        XCTAssertTrue(scheduler.scheduledItems[0].isCancelled)
    }

    func testDisableResetsLastWindowSoSameWindowCanRefocusAfterReenable() {
        let finder = StubFinder()
        finder.matches = [makeMatch(windowNumber: 77), makeMatch(windowNumber: 77)]

        let scheduler = RecordingScheduler()
        var focusedWindowNumbers: [Int] = []

        let manager = FocusFollowsMouseManager(
            finder: finder,
            isProcessTrusted: { true },
            mouseLocationProvider: { .zero },
            primaryScreenHeightProvider: { 100 },
            scheduleWorkItem: scheduler.schedule(delaySeconds:workItem:),
            nowProvider: { Date(timeIntervalSince1970: 0) },
            focusExecutor: { match, _ in
                focusedWindowNumbers.append(match.windowNumber)
            }
        )

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 0)

        manager.setEnabled(false)
        manager.setEnabled(true)

        manager.scheduleFocusCheck(timestamp: 2.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 1)

        XCTAssertEqual(focusedWindowNumbers, [77, 77])
    }
}
