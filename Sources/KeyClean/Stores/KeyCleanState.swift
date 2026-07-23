import Foundation

@MainActor
final class KeyCleanState: ObservableObject {
    @Published private(set) var isLocked = false
    @Published private(set) var permissionState = PermissionState()
    @Published private(set) var lastError: String?

    let keyboardBlocker = KeyboardBlocker()
    let loginItemManager = LoginItemManager()
    private var permissionRefreshTask: Task<Void, Never>?

    var canAttemptLock: Bool {
        permissionState.canAttemptEventTap
    }

    init() {
        keyboardBlocker.onUnlockRequested = { [weak self] in
            Task { @MainActor in
                self?.unlock()
            }
        }

        keyboardBlocker.onError = { [weak self] message in
            Task { @MainActor in
                self?.isLocked = false
                self?.lastError = message
                self?.refreshPermissions()
            }
        }

        startPermissionPolling()
    }

    deinit {
        permissionRefreshTask?.cancel()
    }

    func refreshPermissions() {
        permissionState = PermissionManager.shared.currentState()
    }

    private func startPermissionPolling() {
        permissionRefreshTask = Task { @MainActor [weak self] in
            while !Task.isCancelled {
                self?.refreshPermissions()
                self?.validateActiveLock()
                try? await Task.sleep(nanoseconds: 1_500_000_000)
            }
        }
    }

    private func validateActiveLock() {
        guard isLocked else { return }

        if keyboardBlocker.validateEventTap() {
            return
        }

        isLocked = false
        lastError = "Keyboard lock was released because the event tap was no longer active."
        keyboardBlocker.stop()
    }

    func registerForAccessibilityIfNeeded() {
        refreshPermissions()
        guard !permissionState.accessibilityGranted else { return }

        PermissionManager.shared.requestAccessibilityPermission()
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            refreshPermissions()
        }
    }

    func toggleLock() {
        isLocked ? unlock() : lock()
    }

    func lock() {
        refreshPermissions()
        lastError = nil

        if keyboardBlocker.start() {
            isLocked = true
            refreshPermissions()
        } else {
            isLocked = false
            lastError = keyboardBlocker.lastError ?? "Could not create the keyboard event tap."
            refreshPermissions()
        }
    }

    func unlock() {
        keyboardBlocker.stop()
        isLocked = false
        keyboardBlocker.resetEmergencyState()
    }

    func requestAccessibility() {
        PermissionManager.shared.requestAccessibilityPermission()
        refreshPermissions()
    }

    func requestInputMonitoring() {
        PermissionManager.shared.requestInputMonitoringPermission()
        refreshPermissions()
    }

    func openAccessibilitySettings() {
        PermissionManager.shared.openAccessibilitySettings()
    }

    func openInputMonitoringSettings() {
        PermissionManager.shared.openInputMonitoringSettings()
    }
}
