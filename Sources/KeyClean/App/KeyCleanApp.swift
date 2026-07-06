import AppKit
import SwiftUI

@main
struct KeyCleanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusController: StatusBarController?
    private var terminationGuard: TerminationGuard?
    private let appState = KeyCleanState()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        terminateOtherInstances()
        terminationGuard = TerminationGuard(appState: appState)
        appState.unlock()
        statusController = StatusBarController(appState: appState)
        appState.refreshPermissions()
        appState.registerForAccessibilityIfNeeded()
        UpdateChecker.shared.start()
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        appState.unlock()
        return .terminateNow
    }

    func applicationWillTerminate(_ notification: Notification) {
        appState.unlock()
        UpdateChecker.shared.stop()
    }

    private func terminateOtherInstances() {
        guard let bundleIdentifier = Bundle.main.bundleIdentifier else { return }

        let currentPID = ProcessInfo.processInfo.processIdentifier
        let otherInstances = NSRunningApplication.runningApplications(withBundleIdentifier: bundleIdentifier)
            .filter { $0.processIdentifier != currentPID }

        for instance in otherInstances {
            instance.terminate()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.75) {
            for instance in otherInstances where !instance.isTerminated {
                instance.forceTerminate()
            }
        }
    }
}
