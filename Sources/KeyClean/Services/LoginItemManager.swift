import ServiceManagement

@MainActor
final class LoginItemManager: ObservableObject {
    @Published private(set) var status: SMAppService.Status
    @Published private(set) var lastError: String?

    private let service: SMAppService

    init(service: SMAppService = .mainApp) {
        self.service = service
        self.status = service.status
    }

    var isEnabled: Bool {
        status == .enabled
    }

    var statusMessage: String {
        if let lastError {
            return lastError
        }

        switch status {
        case .enabled:
            return "KeyClean starts automatically after you log in"
        case .requiresApproval:
            return "Approval required in System Settings"
        case .notFound:
            return "Login item is unavailable"
        case .notRegistered:
            return "Start KeyClean automatically after you log in"
        @unknown default:
            return "Login item status is unavailable"
        }
    }

    func refresh() {
        status = service.status
        lastError = nil
    }

    func setEnabled(_ shouldEnable: Bool) {
        lastError = nil
        status = service.status

        if shouldEnable, status == .requiresApproval {
            lastError = "Enable KeyClean in System Settings"
            SMAppService.openSystemSettingsLoginItems()
            return
        }

        do {
            if shouldEnable {
                guard status != .enabled else { return }
                try service.register()
            } else {
                guard status != .notRegistered else { return }
                try service.unregister()
            }

            status = service.status
        } catch {
            status = service.status

            if status == .requiresApproval {
                lastError = "Enable KeyClean in System Settings"
                SMAppService.openSystemSettingsLoginItems()
            } else {
                lastError = "Could not update login setting"
            }
        }
    }
}
