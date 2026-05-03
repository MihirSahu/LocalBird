import AppKit
import Foundation

struct ActiveWindowMetadata: Equatable, Sendable {
    var bundleID: String?
    var appName: String?
    var windowTitle: String?
}

struct MetadataService: Sendable {
    func activeWindowMetadata() -> ActiveWindowMetadata {
        let frontmost = NSWorkspace.shared.frontmostApplication
        let pid = frontmost?.processIdentifier
        let windowTitle = pid.flatMap { titleForFrontmostWindow(processID: $0) }
        return ActiveWindowMetadata(
            bundleID: frontmost?.bundleIdentifier,
            appName: frontmost?.localizedName,
            windowTitle: windowTitle
        )
    }

    private func titleForFrontmostWindow(processID: pid_t) -> String? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windowInfo = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else {
            return nil
        }
        return windowInfo.first { info in
            let ownerPID = info[kCGWindowOwnerPID as String] as? pid_t
            let layer = info[kCGWindowLayer as String] as? Int
            return ownerPID == processID && layer == 0
        }?[kCGWindowName as String] as? String
    }
}
