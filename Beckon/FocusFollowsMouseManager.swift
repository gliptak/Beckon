import ApplicationServices
import AppKit
import Foundation

protocol WindowFinding {
    var debugLastLookup: String { get }
    func windowUnderMouse(at mouseLocation: CGPoint) -> WindowMatch?
}

extension WindowFinder: WindowFinding {}

final class FocusFollowsMouseManager: @unchecked Sendable {
    static let shared = FocusFollowsMouseManager()

    typealias Scheduler = (_ delaySeconds: Double, _ workItem: DispatchWorkItem) -> Void
    typealias FocusExecutor = (_ match: WindowMatch, _ raiseOnFocus: Bool) -> Void

    var hoverDelayMilliseconds: Double = 25
    var raiseOnFocus: Bool = true
    var velocitySensitivity: Double = 0.08

    // Debug properties (accessed from main thread only)
    var debugLastEventTime: String = "—"
    var debugLastWindowInfo: String = "—"

    // Velocity-adaptive dwell: scale effective delay with pointer speed.
    // With sensitivity 0.08, 800 pts/s adds ~64 ms; 3000 pts/s adds ~240 ms.
    private static let maxEffectiveDelayMs: Double = 500

    private var monitor: Any?
    private let finder: WindowFinding
    private var pendingWorkItem: DispatchWorkItem?
    private var lastWindowNumber: Int?
    private var lastEventTimestamp: TimeInterval = 0
    private let isProcessTrusted: () -> Bool
    private let mouseLocationProvider: () -> CGPoint
    private let primaryScreenHeightProvider: () -> CGFloat
    private let scheduleWorkItem: Scheduler
    private let nowProvider: () -> Date
    private let focusExecutor: FocusExecutor

    private static func defaultFocusExecutor(match: WindowMatch, raiseOnFocus: Bool) {
        if let app = NSRunningApplication(processIdentifier: match.processID) {
            app.activate(options: [.activateIgnoringOtherApps])
        }

        let focusedValue = kCFBooleanTrue!
        _ = AXUIElementSetAttributeValue(match.windowElement, kAXMainAttribute as CFString, focusedValue)
        _ = AXUIElementSetAttributeValue(match.windowElement, kAXFocusedAttribute as CFString, focusedValue)

        if raiseOnFocus {
            _ = AXUIElementPerformAction(match.windowElement, kAXRaiseAction as CFString)
        }
    }

    init(
        finder: WindowFinding = WindowFinder(),
        isProcessTrusted: @escaping () -> Bool = AXIsProcessTrusted,
        mouseLocationProvider: @escaping () -> CGPoint = { NSEvent.mouseLocation },
        primaryScreenHeightProvider: @escaping () -> CGFloat = { NSScreen.screens.first?.frame.height ?? 0 },
        scheduleWorkItem: @escaping Scheduler = { delaySeconds, workItem in
            DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds, execute: workItem)
        },
        nowProvider: @escaping () -> Date = Date.init,
        focusExecutor: @escaping FocusExecutor = FocusFollowsMouseManager.defaultFocusExecutor(match:raiseOnFocus:)
    ) {
        self.finder = finder
        self.isProcessTrusted = isProcessTrusted
        self.mouseLocationProvider = mouseLocationProvider
        self.primaryScreenHeightProvider = primaryScreenHeightProvider
        self.scheduleWorkItem = scheduleWorkItem
        self.nowProvider = nowProvider
        self.focusExecutor = focusExecutor
    }

    func setEnabled(_ enabled: Bool) {
        if enabled {
            startIfNeeded()
        } else {
            stop()
        }
    }

    private func startIfNeeded() {
        guard monitor == nil else {
            return
        }

        // Global monitor callback fires on background thread; extract value types before dispatching to main.
        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            let timestamp = event.timestamp
            let deltaX = event.deltaX
            let deltaY = event.deltaY
            DispatchQueue.main.async { [weak self] in
                self?.scheduleFocusCheck(timestamp: timestamp, deltaX: deltaX, deltaY: deltaY)
            }
        }
    }

    private func stop() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        lastWindowNumber = nil

        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }

    private func scheduleFocusCheck(timestamp: TimeInterval, deltaX: CGFloat, deltaY: CGFloat) {
        let appKitPoint = mouseLocationProvider()
        let primaryScreenHeight = primaryScreenHeightProvider()
        let mousePoint = CGPoint(x: appKitPoint.x, y: primaryScreenHeight - appKitPoint.y)

        scheduleFocusCheck(timestamp: timestamp, deltaX: deltaX, deltaY: deltaY, mousePoint: mousePoint, isTrusted: isProcessTrusted())
    }

    func scheduleFocusCheck(timestamp: TimeInterval, deltaX: CGFloat, deltaY: CGFloat, mousePoint: CGPoint, isTrusted: Bool) {
        pendingWorkItem?.cancel()

        // Velocity-adaptive dwell: fast pointer movement inflates the effective delay,
        // making transient window crossings less likely to steal focus.
        let effectiveDelayMs = HoverDelayCalculator.effectiveDelayMs(
            baseDelayMs: hoverDelayMilliseconds,
            lastEventTimestamp: lastEventTimestamp,
            currentTimestamp: timestamp,
            deltaX: deltaX,
            deltaY: deltaY,
            velocitySensitivity: velocitySensitivity,
            maxDelayMs: Self.maxEffectiveDelayMs
        )
        lastEventTimestamp = timestamp

        // Check window and permission state immediately (before debounce delay)
        // so debug display updates even if focus action is debounced.
        guard isTrusted else {
            debugLastWindowInfo = "AX permission denied"
            return
        }

        guard let match = finder.windowUnderMouse(at: mousePoint) else {
            debugLastWindowInfo = finder.debugLastLookup
            return
        }

        debugLastWindowInfo = "Window #\(match.windowNumber) (PID \(match.processID))"

        // Schedule focus action after velocity-adjusted debounce delay
        let workItem = DispatchWorkItem { [weak self] in
            self?.applyFocusToWindow(match)
        }
        pendingWorkItem = workItem

        let now = nowProvider()
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        formatter.dateStyle = .none
        debugLastEventTime = formatter.string(from: now)

        let delaySeconds = effectiveDelayMs / 1000.0
        scheduleWorkItem(delaySeconds, workItem)
    }

    private func applyFocusToWindow(_ match: WindowMatch) {
        if lastWindowNumber == match.windowNumber {
            return
        }

        lastWindowNumber = match.windowNumber

        focusExecutor(match, raiseOnFocus)
    }
}
