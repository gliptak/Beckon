import ApplicationServices
import Cocoa

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Accessibility permission is surfaced via the menu bar warning label and
        // "Open Accessibility Settings" button in MenuBarView. No auto-prompt on
        // launch — macOS would re-prompt on every debug build anyway (code signature
        // changes per build), which is confusing during development and unnecessary
        // in release builds where the user can act via the menu.
    }
}
