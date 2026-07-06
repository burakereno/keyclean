import AppKit
import ApplicationServices
import CoreGraphics
import Foundation

struct PermissionState: Equatable {
    var accessibilityGranted: Bool
    var inputMonitoringGranted: Bool

    init(accessibilityGranted: Bool = false, inputMonitoringGranted: Bool = false) {
        self.accessibilityGranted = accessibilityGranted
        self.inputMonitoringGranted = inputMonitoringGranted
    }

    var canAttemptEventTap: Bool {
        accessibilityGranted || inputMonitoringGranted
    }
}

final class PermissionManager {
    static let shared = PermissionManager()

    private init() {}

    func currentState() -> PermissionState {
        PermissionState(
            accessibilityGranted: isAccessibilityTrusted(prompt: false),
            inputMonitoringGranted: isInputMonitoringTrusted()
        )
    }

    func requestAccessibilityPermission() {
        _ = isAccessibilityTrusted(prompt: true)
    }

    func requestInputMonitoringPermission() {
        if #available(macOS 10.15, *) {
            _ = CGRequestListenEventAccess()
        }
    }

    func openAccessibilitySettings() {
        openPrivacyPane("Privacy_Accessibility")
    }

    func openInputMonitoringSettings() {
        openPrivacyPane("Privacy_ListenEvent")
    }

    private func isAccessibilityTrusted(prompt: Bool) -> Bool {
        let options = [
            kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: prompt
        ] as CFDictionary
        return AXIsProcessTrustedWithOptions(options)
    }

    private func isInputMonitoringTrusted() -> Bool {
        if #available(macOS 10.15, *) {
            return CGPreflightListenEventAccess()
        }
        return false
    }

    private func openPrivacyPane(_ anchor: String) {
        let modernURL = URL(string: "x-apple.systempreferences:com.apple.preference.security?\(anchor)")
        let legacyURL = URL(fileURLWithPath: "/System/Library/PreferencePanes/Security.prefPane")

        if let modernURL, NSWorkspace.shared.open(modernURL) {
            return
        }
        NSWorkspace.shared.open(legacyURL)
    }
}
