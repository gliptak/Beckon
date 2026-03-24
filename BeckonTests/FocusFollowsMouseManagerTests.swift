import ApplicationServices
import CoreGraphics
import XCTest
@testable import Beckon

// Shared test doubles used by both test classes below.

final class StubWindowFinder: WindowFinding {
    var debugLastLookup: String = "stub"
    var matches: [WindowMatch?] = []

    func windowUnderMouse(at mouseLocation: CGPoint) -> WindowMatch? {
        guard !matches.isEmpty else { return nil }
        return matches.removeFirst()
    }
}

final class RecordingScheduler {
    private(set) var scheduledItems: [DispatchWorkItem] = []

    func schedule(delaySeconds: Double, workItem: DispatchWorkItem) {
        scheduledItems.append(workItem)
    }

    func runItem(at index: Int) {
        let item = scheduledItems[index]
        guard !item.isCancelled else { return }
        item.perform()
    }
}

// MARK: - Helpers shared across test classes

private func makeTestMatch(windowNumber: Int, pid: pid_t = 1001) -> WindowMatch {
    WindowMatch(
        processID: pid,
        windowElement: AXUIElementCreateSystemWide(),
        windowNumber: windowNumber
    )
}

private func makeManager(
    finder: WindowFinding,
    scheduler: RecordingScheduler,
    focusExecutor: @escaping FocusFollowsMouseManager.FocusExecutor = { _, _ in }
) -> FocusFollowsMouseManager {
    FocusFollowsMouseManager(
        finder: finder,
        isProcessTrusted: { true },
        mouseLocationProvider: { .zero },
        primaryScreenHeightProvider: { 100 },
        scheduleWorkItem: scheduler.schedule(delaySeconds:workItem:),
        nowProvider: { Date(timeIntervalSince1970: 0) },
        focusExecutor: focusExecutor
    )
}

// MARK: - Core behaviour tests

final class FocusFollowsMouseManagerTests: XCTestCase {
    private func makeMatch(windowNumber: Int, pid: pid_t = 1001) -> WindowMatch {
        makeTestMatch(windowNumber: windowNumber, pid: pid)
    }

    func testNewScheduleCancelsPreviousPendingWorkItem() {
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 1), makeMatch(windowNumber: 2)]

        let scheduler = RecordingScheduler()
        let manager = makeManager(finder: finder, scheduler: scheduler)

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        manager.scheduleFocusCheck(timestamp: 2.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)

        XCTAssertEqual(scheduler.scheduledItems.count, 2)
        XCTAssertTrue(scheduler.scheduledItems[0].isCancelled)
        XCTAssertFalse(scheduler.scheduledItems[1].isCancelled)
    }

    func testDuplicateWindowDoesNotReapplyFocus() {
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 7), makeMatch(windowNumber: 7)]

        let scheduler = RecordingScheduler()
        var focusedWindowNumbers: [Int] = []

        let manager = makeManager(finder: finder, scheduler: scheduler) { match, _ in
            focusedWindowNumbers.append(match.windowNumber)
        }

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 0)

        manager.scheduleFocusCheck(timestamp: 2.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 1)

        XCTAssertEqual(focusedWindowNumbers, [7])
    }

    func testRaiseFlagIsForwardedToFocusExecutor() {
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 11)]

        let scheduler = RecordingScheduler()
        var recordedRaiseValues: [Bool] = []

        let manager = makeManager(finder: finder, scheduler: scheduler) { _, raise in
            recordedRaiseValues.append(raise)
        }

        manager.raiseOnFocus = false
        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 0)

        XCTAssertEqual(recordedRaiseValues, [false])
    }

    func testUntrustedPathSkipsSchedulingAndSetsDebugInfo() {
        let finder = StubWindowFinder()
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
        let finder = StubWindowFinder()
        finder.debugLastLookup = "No window at point"
        finder.matches = [nil]

        let scheduler = RecordingScheduler()
        let manager = makeManager(finder: finder, scheduler: scheduler)

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)

        XCTAssertEqual(manager.debugLastWindowInfo, "No window at point")
        XCTAssertEqual(scheduler.scheduledItems.count, 0)
    }

    func testMatchedWindowUpdatesDebugInfoAndEventTime() {
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 42, pid: 2002)]

        let scheduler = RecordingScheduler()
        let manager = makeManager(finder: finder, scheduler: scheduler)

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)

        XCTAssertEqual(manager.debugLastWindowInfo, "Window #42 (PID 2002)")
        XCTAssertNotEqual(manager.debugLastEventTime, "—")
        XCTAssertEqual(scheduler.scheduledItems.count, 1)
    }

    func testDisableCancelsPendingWorkItem() {
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 9)]

        let scheduler = RecordingScheduler()
        let manager = makeManager(finder: finder, scheduler: scheduler)

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        XCTAssertEqual(scheduler.scheduledItems.count, 1)
        XCTAssertFalse(scheduler.scheduledItems[0].isCancelled)

        manager.setEnabled(false)

        XCTAssertTrue(scheduler.scheduledItems[0].isCancelled)
    }

    func testDisableResetsLastWindowSoSameWindowCanRefocusAfterReenable() {
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 77), makeMatch(windowNumber: 77)]

        let scheduler = RecordingScheduler()
        var focusedWindowNumbers: [Int] = []

        let manager = makeManager(finder: finder, scheduler: scheduler) { match, _ in
            focusedWindowNumbers.append(match.windowNumber)
        }

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 0)

        manager.setEnabled(false)
        manager.setEnabled(true)

        manager.scheduleFocusCheck(timestamp: 2.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 1)

        XCTAssertEqual(focusedWindowNumbers, [77, 77])
    }
}

// MARK: - Scroll suppression and active-space tests

final class FocusFollowsMouseManagerScrollTests: XCTestCase {
    private func makeMatch(windowNumber: Int) -> WindowMatch { makeTestMatch(windowNumber: windowNumber) }

    func testScrollEventCancelsPendingWorkItem() {
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 1)]
        let scheduler = RecordingScheduler()
        let manager = makeManager(finder: finder, scheduler: scheduler)

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        XCTAssertFalse(scheduler.scheduledItems[0].isCancelled)

        manager.noteScrollEvent(timestamp: 1.1)

        XCTAssertTrue(scheduler.scheduledItems[0].isCancelled)
    }

    func testScrollSuppressionBlocksFocusCheckWithinWindow() {
        // noteScrollEvent at t=10.0 → suppresses until t=10.35
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 2)]
        let scheduler = RecordingScheduler()
        let manager = makeManager(finder: finder, scheduler: scheduler)

        manager.noteScrollEvent(timestamp: 10.0)
        manager.scheduleFocusCheck(timestamp: 10.2, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)

        XCTAssertEqual(scheduler.scheduledItems.count, 0)
        XCTAssertEqual(manager.debugLastWindowInfo, "Suppressed during scroll")
    }

    func testScrollSuppressionExpiresAfterWindow() {
        // noteScrollEvent at t=10.0 → suppresses until t=10.35; t=10.4 should pass through
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 3)]
        let scheduler = RecordingScheduler()
        let manager = makeManager(finder: finder, scheduler: scheduler)

        manager.noteScrollEvent(timestamp: 10.0)
        manager.scheduleFocusCheck(timestamp: 10.4, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)

        XCTAssertEqual(scheduler.scheduledItems.count, 1)
    }

    func testActiveSpaceChangeCancelsPendingWorkItem() {
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 10)]
        let scheduler = RecordingScheduler()
        let manager = makeManager(finder: finder, scheduler: scheduler)

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        XCTAssertFalse(scheduler.scheduledItems[0].isCancelled)

        manager.handleActiveSpaceChange()

        XCTAssertTrue(scheduler.scheduledItems[0].isCancelled)
    }

    func testActiveSpaceChangeResetsLastWindowSoSameWindowRefocuses() {
        let finder = StubWindowFinder()
        finder.matches = [makeMatch(windowNumber: 20), makeMatch(windowNumber: 20)]
        let scheduler = RecordingScheduler()
        var focusedCount = 0
        let manager = makeManager(finder: finder, scheduler: scheduler) { _, _ in focusedCount += 1 }

        manager.scheduleFocusCheck(timestamp: 1.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 0)
        XCTAssertEqual(focusedCount, 1)

        // Space change resets the tracked window — same window should refocus next event.
        manager.handleActiveSpaceChange()

        manager.scheduleFocusCheck(timestamp: 2.0, deltaX: 0, deltaY: 0, mousePoint: .zero, isTrusted: true)
        scheduler.runItem(at: 1)
        XCTAssertEqual(focusedCount, 2)
    }
}

// MARK: - highlightBorder.didSet path

@MainActor
final class FocusFollowsMouseManagerHighlightTests: XCTestCase {
    func testSettingHighlightBorderFalseWhenAlreadyFalseDoesNotCrash() {
        let manager = makeManager(finder: StubWindowFinder(), scheduler: RecordingScheduler())
        manager.highlightBorder = false
        XCTAssertFalse(manager.highlightBorder)
    }

    func testSettingHighlightBorderTrueThenFalseHidesOverlay() {
        let manager = makeManager(finder: StubWindowFinder(), scheduler: RecordingScheduler())
        manager.highlightBorder = true
        manager.highlightBorder = false
        XCTAssertFalse(manager.highlightBorder)
    }
}
