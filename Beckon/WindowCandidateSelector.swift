import CoreGraphics
import Foundation

struct WindowCandidate: Equatable {
    let processID: pid_t
    let windowNumber: Int
}

enum WindowCandidateSelector {
    static func candidates(
        under mouseLocation: CGPoint,
        from infoList: [[String: Any]],
        excludingProcessID currentProcessID: pid_t
    ) -> [WindowCandidate] {
        // If the topmost foreign window at the pointer is not a normal app window
        // (layer 0), avoid focusing a window underneath transient UI like menus.
        if let topmostLayer = topmostForeignLayer(
            under: mouseLocation,
            from: infoList,
            excludingProcessID: currentProcessID
        ), topmostLayer != 0 {
            return []
        }

        var result: [WindowCandidate] = []

        for info in infoList {
            guard let layer = info[kCGWindowLayer as String] as? Int,
                  layer == 0,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.contains(mouseLocation),
                  let windowNumber = info[kCGWindowNumber as String] as? Int,
                  let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pid != currentProcessID else {
                continue
            }

            result.append(WindowCandidate(processID: pid, windowNumber: windowNumber))
        }

        return result
    }

    private static func topmostForeignLayer(
        under mouseLocation: CGPoint,
        from infoList: [[String: Any]],
        excludingProcessID currentProcessID: pid_t
    ) -> Int? {
        for info in infoList {
            guard let pid = info[kCGWindowOwnerPID as String] as? pid_t,
                  pid != currentProcessID,
                  let boundsDict = info[kCGWindowBounds as String] as? [String: Any],
                  let bounds = CGRect(dictionaryRepresentation: boundsDict as CFDictionary),
                  bounds.contains(mouseLocation),
                  let layer = info[kCGWindowLayer as String] as? Int else {
                continue
            }

            return layer
        }

        return nil
    }
}