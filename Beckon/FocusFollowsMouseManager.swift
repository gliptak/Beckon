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
    var raiseOnFocus: Bool = false
    var velocitySensitivity: Double = 0.08
    var highlightBorder: Bool = true {
        didSet {
            if !highlightBorder {
                stopBorderTracking()
                hideBorderOverlay()
            }
        }
    }
    var borderWidth: Double = 2.0

    // Debug properties (accessed from main thread only)
    var debugLastEventTime: String = "—"
    var debugLastWindowInfo: String = "—"

    // Velocity-adaptive dwell: scale effective delay with pointer speed.
    // With sensitivity 0.08, 800 pts/s adds ~64 ms; 3000 pts/s adds ~240 ms.
    private static let maxEffectiveDelayMs: Double = 500
    private static let scrollSuppressionSeconds: TimeInterval = 0.35

    private var monitor: Any?
    private let finder: WindowFinding
    private var pendingWorkItem: DispatchWorkItem?
    private var lastWindowNumber: Int?
    private var lastEventTimestamp: TimeInterval = 0
    private var scrollMonitor: Any?
    private var activeSpaceObserver: NSObjectProtocol?
    private var suppressFocusUntilTimestamp: TimeInterval = 0
    private var borderTrackingTimer: Timer?
    private var trackedWindowElement: AXUIElement?
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

        // Suppress focus changes while the user is actively scrolling (e.g. long popup menus).
        scrollMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.scrollWheel]) { [weak self] event in
            let timestamp = event.timestamp
            DispatchQueue.main.async { [weak self] in
                self?.noteScrollEvent(timestamp: timestamp)
            }
        }

        activeSpaceObserver = NotificationCenter.default.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: NSWorkspace.shared,
            queue: .main
        ) { [weak self] _ in
            self?.handleActiveSpaceChange()
        }
    }

    private func stop() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        lastWindowNumber = nil
        suppressFocusUntilTimestamp = 0
        stopBorderTracking()
        hideBorderOverlay()

        if let monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
        if let scrollMonitor {
            NSEvent.removeMonitor(scrollMonitor)
            self.scrollMonitor = nil
        }
        if let activeSpaceObserver {
            NotificationCenter.default.removeObserver(activeSpaceObserver)
            self.activeSpaceObserver = nil
        }
    }

    private func scheduleFocusCheck(timestamp: TimeInterval, deltaX: CGFloat, deltaY: CGFloat) {
        let appKitPoint = mouseLocationProvider()
        let primaryScreenHeight = primaryScreenHeightProvider()
        let mousePoint = CGPoint(x: appKitPoint.x, y: primaryScreenHeight - appKitPoint.y)

        scheduleFocusCheck(
            timestamp: timestamp,
            deltaX: deltaX,
            deltaY: deltaY,
            mousePoint: mousePoint,
            isTrusted: isProcessTrusted()
        )
    }

    func scheduleFocusCheck(timestamp: TimeInterval, deltaX: CGFloat, deltaY: CGFloat, mousePoint: CGPoint, isTrusted: Bool) {
        if timestamp <= suppressFocusUntilTimestamp {
            debugLastWindowInfo = "Suppressed during scroll"
            return
        }

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

        // Schedule focus action after velocity-adjusted debounce delay.
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

    private func noteScrollEvent(timestamp: TimeInterval) {
        suppressFocusUntilTimestamp = max(
            suppressFocusUntilTimestamp,
            timestamp + Self.scrollSuppressionSeconds
        )
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
    }

    private func applyFocusToWindow(_ match: WindowMatch) {
        if lastWindowNumber == match.windowNumber {
            // Same window can resize (maximize/fullscreen) without a focus change.
            // Refresh the border frame so the overlay stays aligned.
            if highlightBorder {
                _ = showBorderHighlight(for: match.windowElement)
                startBorderTracking(for: match.windowElement)
            }
            return
        }

        lastWindowNumber = match.windowNumber
        focusExecutor(match, raiseOnFocus)

        if highlightBorder {
            _ = showBorderHighlight(for: match.windowElement)
            startBorderTracking(for: match.windowElement)
        } else {
            stopBorderTracking()
            hideBorderOverlay()
        }
    }

    private func showBorderHighlight(for element: AXUIElement) -> Bool {
        var cfValue: CFTypeRef?
        guard AXUIElementCopyAttributeValue(element, "AXFrame" as CFString, &cfValue) == .success,
              let axVal = cfValue,
              CFGetTypeID(axVal) == AXValueGetTypeID() else { return false }

        var cgFrame = CGRect.zero
        // Cast is safe: we verified the type ID above.
        AXValueGetValue(axVal as! AXValue, .cgRect, &cgFrame)

        let screenHeight = primaryScreenHeightProvider()
        withBorderOverlay { highlight in
            let resolvedColor = BorderAutoColorResolver.color(for: NSApp.effectiveAppearance)
            highlight.borderColor = resolvedColor
            highlight.borderWidth = CGFloat(borderWidth)
            highlight.show(forCGFrame: cgFrame, screenHeight: screenHeight)
        }
        return true
    }

    private func startBorderTracking(for element: AXUIElement) {
        trackedWindowElement = element
        if borderTrackingTimer != nil {
            return
        }

        let timer = Timer(timeInterval: 1.0 / 30.0, repeats: true) { [weak self] _ in
            self?.refreshTrackedBorderFrame()
        }
        timer.tolerance = 1.0 / 120.0
        RunLoop.main.add(timer, forMode: .common)
        borderTrackingTimer = timer
    }

    private func refreshTrackedBorderFrame() {
        guard highlightBorder, let trackedWindowElement else {
            stopBorderTracking()
            hideBorderOverlay()
            return
        }

        if !showBorderHighlight(for: trackedWindowElement) {
            // During Spaces/Mission Control/fullscreen transitions, AX frame reads can fail.
            // Hide stale border immediately and wait for next stable focus event.
            stopBorderTracking()
            lastWindowNumber = nil
            hideBorderOverlay()
        }
    }

    private func stopBorderTracking() {
        borderTrackingTimer?.invalidate()
        borderTrackingTimer = nil
        trackedWindowElement = nil
    }

    private func handleActiveSpaceChange() {
        pendingWorkItem?.cancel()
        pendingWorkItem = nil
        lastWindowNumber = nil
        stopBorderTracking()
        hideBorderOverlay()
    }

    private func hideBorderOverlay() {
        MainActor.assumeIsolated {
            BorderHighlightWindow.shared.hide()
        }
    }

    private func withBorderOverlay(_ body: @MainActor (BorderHighlightWindow) -> Void) {
        MainActor.assumeIsolated {
            body(BorderHighlightWindow.shared)
        }
    }
}
