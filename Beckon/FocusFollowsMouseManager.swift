import ApplicationServices
import AppKit
import Foundation

@MainActor
final class FocusFollowsMouseManager {
    static let shared = FocusFollowsMouseManager()

    var hoverDelayMilliseconds: Double = 25
    var raiseOnFocus: Bool = true

    private var monitor: Any?
    private let finder = WindowFinder()
    private var pendingWorkItem: DispatchWorkItem?
    private var lastWindowNumber: Int?

    private init() {}

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

        monitor = NSEvent.addGlobalMonitorForEvents(matching: [.mouseMoved]) { [weak self] event in
            self?.scheduleFocusCheck(for: event)
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

    private func scheduleFocusCheck(for event: NSEvent) {
        pendingWorkItem?.cancel()

        let workItem = DispatchWorkItem { [weak self] in
            self?.focusWindowUnderCursor()
        }
        pendingWorkItem = workItem

        let delaySeconds = max(0, hoverDelayMilliseconds) / 1000.0
        DispatchQueue.main.asyncAfter(deadline: .now() + delaySeconds, execute: workItem)
    }

    private func focusWindowUnderCursor() {
        guard AXIsProcessTrusted() else {
            return
        }

        // NSEvent.mouseLocation is in AppKit screen coordinates (origin: bottom-left of
        // primary screen, Y increases upward). CGWindowList and AX APIs use Quartz/CG
        // coordinates (origin: top-left of primary screen, Y increases downward).
        // Convert once here so WindowFinder can use a single coordinate system throughout.
        let appKitPoint = NSEvent.mouseLocation
        let primaryScreenHeight = NSScreen.screens.first?.frame.height ?? 0
        let mousePoint = CGPoint(x: appKitPoint.x, y: primaryScreenHeight - appKitPoint.y)
        guard let match = finder.windowUnderMouse(at: mousePoint) else {
            return
        }

        if lastWindowNumber == match.windowNumber {
            return
        }

        lastWindowNumber = match.windowNumber

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
}
