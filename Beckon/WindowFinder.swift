import ApplicationServices
import AppKit

struct WindowMatch {
    let processID: pid_t
    let windowElement: AXUIElement
    let windowNumber: Int
}

final class WindowFinder {
    var debugLastLookup: String = "—"

    func windowUnderMouse(at mouseLocation: CGPoint) -> WindowMatch? {
        guard let infoList = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] else {
            debugLastLookup = "CGWindowList returned nil"
            return nil
        }

        debugLastLookup = "Found \(infoList.count) windows; checking point (\(Int(mouseLocation.x)),\(Int(mouseLocation.y)))"

        let candidates = WindowCandidateSelector.candidates(
            under: mouseLocation,
            from: infoList,
            excludingProcessID: ProcessInfo.processInfo.processIdentifier
        )

        for candidate in candidates {
            let windowNumber = candidate.windowNumber
            let pid = candidate.processID

            debugLastLookup = "Matched bounds for window #\(windowNumber)"
            let appElement = AXUIElementCreateApplication(pid)
            if let exactWindow = matchingAXWindow(in: appElement, mouseLocation: mouseLocation) {
                debugLastLookup = "Found exact AX match"
                return WindowMatch(processID: pid, windowElement: exactWindow, windowNumber: windowNumber)
            }

            if let firstWindow = firstAXWindow(in: appElement) {
                debugLastLookup = "Using first AX window"
                return WindowMatch(processID: pid, windowElement: firstWindow, windowNumber: windowNumber)
            }

            debugLastLookup = "No AX windows for PID \(pid)"
        }

        debugLastLookup = "No window at point"
        return nil
    }

    private func firstAXWindow(in appElement: AXUIElement) -> AXUIElement? {
        guard let windows = copyAXWindows(from: appElement), !windows.isEmpty else {
            return nil
        }
        return windows[0]
    }

    private func matchingAXWindow(in appElement: AXUIElement, mouseLocation: CGPoint) -> AXUIElement? {
        guard let windows = copyAXWindows(from: appElement) else {
            return nil
        }

        for window in windows {
            guard let frame = frameForWindow(window), frame.contains(mouseLocation) else {
                continue
            }
            return window
        }

        return nil
    }

    private func copyAXWindows(from appElement: AXUIElement) -> [AXUIElement]? {
        var value: CFTypeRef?
        let result = AXUIElementCopyAttributeValue(appElement, kAXWindowsAttribute as CFString, &value)
        guard result == .success, let array = value as? [AXUIElement] else {
            return nil
        }
        return array
    }

    private func frameForWindow(_ window: AXUIElement) -> CGRect? {
        var positionValue: CFTypeRef?
        var sizeValue: CFTypeRef?

        let positionResult = AXUIElementCopyAttributeValue(window, kAXPositionAttribute as CFString, &positionValue)
        let sizeResult = AXUIElementCopyAttributeValue(window, kAXSizeAttribute as CFString, &sizeValue)

        guard positionResult == .success,
              sizeResult == .success,
              let axPosition = positionValue,
              let axSize = sizeValue else {
            return nil
        }

        var point = CGPoint.zero
        var size = CGSize.zero

        guard AXValueGetType(axPosition as! AXValue) == .cgPoint,
              AXValueGetType(axSize as! AXValue) == .cgSize,
              AXValueGetValue(axPosition as! AXValue, .cgPoint, &point),
              AXValueGetValue(axSize as! AXValue, .cgSize, &size) else {
            return nil
        }

        return CGRect(origin: point, size: size)
    }
}
