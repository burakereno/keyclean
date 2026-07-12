import AppKit
import SwiftUI

struct StatusPanelView: View {
    @ObservedObject var appState: KeyCleanState
    let onPreferredHeightChange: (CGFloat) -> Void
    @ObservedObject private var updater = UpdateChecker.shared
    @State private var showSettings = false
    @State private var showFooterUpToDate = false
    @State private var headerHeight: CGFloat = 0
    @State private var dashboardContentHeight: CGFloat = 0
    @State private var settingsContentHeight: CGFloat = 0
    @State private var footerHeight: CGFloat = 0
    @State private var lastReportedHeight: CGFloat = 0

    var body: some View {
        VStack(spacing: 0) {
            header
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    headerHeight = height
                    reportPreferredHeight()
                }

            Divider().opacity(0.5)

            ZStack {
                if showSettings {
                    ScrollView {
                        settingsContent
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                settingsContentHeight = height
                                reportPreferredHeight()
                            }
                    }
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .move(edge: .trailing).combined(with: .opacity)
                    ))
                } else {
                    ScrollView {
                        content
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .onGeometryChange(for: CGFloat.self) { proxy in
                                proxy.size.height
                            } action: { height in
                                dashboardContentHeight = height
                                reportPreferredHeight()
                            }
                    }
                    .scrollIndicators(.never)
                    .transition(.asymmetric(
                        insertion: .move(edge: .leading).combined(with: .opacity),
                        removal: .move(edge: .leading).combined(with: .opacity)
                    ))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipped()
            .animation(.snappy(duration: 0.24), value: showSettings)

            Divider().opacity(0.5)

            footer
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.height
                } action: { height in
                    footerHeight = height
                    reportPreferredHeight()
                }
        }
        .frame(width: KeyCleanPopoverLayout.width)
        .preferredColorScheme(.dark)
        .onChange(of: showSettings) { _, _ in
            reportPreferredHeight()
        }
        .onAppear {
            appState.refreshPermissions()
        }
    }

    private func reportPreferredHeight() {
        let contentHeight = showSettings ? settingsContentHeight : dashboardContentHeight
        guard headerHeight > 0, contentHeight > 0, footerHeight > 0 else { return }

        let dividerHeights: CGFloat = 2
        let preferredHeight = ceil(headerHeight + contentHeight + footerHeight + dividerHeights)
        guard abs(lastReportedHeight - preferredHeight) > 0.5 else { return }

        lastReportedHeight = preferredHeight
        onPreferredHeightChange(preferredHeight)
    }

    private var header: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "keyboard")
                    .font(.system(size: 13, weight: .bold))
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(.primary)

                Text("KeyClean")
                    .font(.system(size: 14, weight: .bold))
            }

            Spacer()

            StatusPill(
                title: appState.isLocked ? "LOCKED" : (appState.canAttemptLock ? "READY" : "PERMISSION"),
                tint: appState.isLocked ? .red : (appState.canAttemptLock ? .green : .orange)
            )

            Button {
                withAnimation(.snappy(duration: 0.24)) {
                    showSettings.toggle()
                }
            } label: {
                Image(systemName: showSettings ? "xmark.circle.fill" : "gearshape")
                    .font(.system(size: 14))
                    .foregroundStyle(showSettings ? .primary : .secondary)
                    .frame(width: 24, height: 24)
            }
            .buttonStyle(.plain)
            .help(showSettings ? "Close Settings" : "Settings")
            .accessibilityLabel(showSettings ? "Close Settings" : "Settings")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    private var content: some View {
        VStack(alignment: .leading, spacing: 12) {
            LockStatusCard(appState: appState, blocker: appState.keyboardBlocker)

            if !appState.canAttemptLock {
                PermissionCard(appState: appState)
            }

            if let error = appState.lastError {
                MessageCard(icon: "exclamationmark.triangle.fill", title: "Could not lock", message: error, tint: .orange)
            }

            MessageCard(
                icon: "cursorarrow.click.2",
                title: nil,
                message: "Unlock from this panel, or hold ESC for 3 seconds.",
                tint: .orange,
                compact: true
            )
        }
    }

    private var settingsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            SettingsSectionView(title: "PERMISSIONS") {
                PermissionRow(
                    icon: "figure.wave.circle",
                    title: "Accessibility",
                    subtitle: "Allows KeyClean to discard key events",
                    granted: appState.permissionState.accessibilityGranted,
                    actionTitle: "Open"
                ) {
                    appState.requestAccessibility()
                    appState.openAccessibilitySettings()
                }

                Divider()
                    .opacity(0.35)
                    .padding(.vertical, 5)

                PermissionRow(
                    icon: "keyboard.badge.eye",
                    title: "Input Monitoring",
                    subtitle: "Needed by newer macOS event taps",
                    granted: appState.permissionState.inputMonitoringGranted,
                    actionTitle: "Open"
                ) {
                    appState.requestInputMonitoring()
                    appState.openInputMonitoringSettings()
                }
            }

            SettingsSectionView(title: "SAFETY") {
                InfoRow(
                    icon: "escape",
                    title: "Emergency Unlock",
                    subtitle: "Hold ESC for 3 seconds"
                )

                Divider()
                    .opacity(0.35)
                    .padding(.vertical, 5)

                InfoRow(
                    icon: "hand.tap",
                    title: "Pointer Input",
                    subtitle: "Mouse and trackpad remain usable"
                )
            }

            SettingsSectionView(title: "ABOUT") {
                InfoRow(
                    icon: "sparkles",
                    title: "KeyClean",
                    subtitle: "Version \(appVersion)"
                )
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if updater.updateAvailable, let latestVersion = updater.latestVersion {
                UpdateButton(version: latestVersion)
            } else {
                footerVersionStatus
            }

            Spacer()

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Text(appState.isLocked ? "Unlock first" : "Quit")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(appState.isLocked ? .tertiary : .secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.primary.opacity(0.06))
                    }
            }
            .buttonStyle(.plain)
            .disabled(appState.isLocked)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
    }

    private var footerVersionStatus: some View {
        HStack(spacing: 6) {
            Button {
                Task { await updater.checkForUpdates(force: true) }
            } label: {
                if updater.isChecking {
                    ProgressView()
                        .controlSize(.small)
                        .frame(width: 14, height: 14)
                } else {
                    Image(systemName: "arrow.down.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 14, height: 14)
                }
            }
            .buttonStyle(.plain)
            .disabled(updater.isChecking)
            .help(updater.isChecking ? "Checking for Updates" : "Check for Updates")

            Text(footerUpdateText)
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(footerUpdateColor)
                .lineLimit(1)
        }
        .fixedSize(horizontal: true, vertical: false)
        .animation(.easeInOut(duration: 0.18), value: updater.isChecking)
        .animation(.easeInOut(duration: 0.18), value: updater.lastCheckCompletedAt)
        .onChange(of: updater.lastCheckCompletedAt) { _, _ in
            guard updater.isUpToDate else { return }
            Task {
                showFooterUpToDate = true
                try? await Task.sleep(nanoseconds: 1_000_000_000)
                showFooterUpToDate = false
            }
        }
    }

    private var footerUpdateText: String {
        if updater.isChecking { return "Checking" }
        if updater.lastError != nil { return "Check failed" }
        if showFooterUpToDate { return "Up to date" }
        return "v\(appVersion)"
    }

    private var footerUpdateColor: Color {
        if updater.lastError != nil { return .red }
        if showFooterUpToDate { return .green }
        return .secondary
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"
    }
}

private struct LockStatusCard: View {
    @ObservedObject var appState: KeyCleanState
    @ObservedObject var blocker: KeyboardBlocker

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(statusTint.opacity(0.12))
                        .frame(width: 58, height: 58)

                    Image(systemName: appState.isLocked ? "lock.fill" : "lock.open")
                        .font(.system(size: 24, weight: .bold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(statusTint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(appState.isLocked ? "Keyboard locked" : "Ready to clean")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundStyle(.primary)

                    Text(statusMessage)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                Spacer(minLength: 0)
            }

            if appState.isLocked && blocker.isEscapeHeld {
                VStack(alignment: .leading, spacing: 7) {
                    HStack {
                        Text("ESC hold")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                            .tracking(0.4)

                        Spacer()

                        Text("\(Int(ceil((1 - blocker.unlockProgress) * 3)))s")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.red)
                    }

                    ProgressView(value: blocker.unlockProgress)
                        .progressViewStyle(.linear)
                        .tint(.red)
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }

            Button {
                appState.toggleLock()
            } label: {
                Label(appState.isLocked ? "Unlock Keyboard" : "Lock Keyboard", systemImage: appState.isLocked ? "lock.open.fill" : "lock.fill")
            }
            .buttonStyle(KeyCleanPrimaryButtonStyle(tint: appState.isLocked ? .red : .blue))
            .help(appState.isLocked ? "Unlock Keyboard" : "Lock Keyboard")
        }
        .padding(14)
        .keyCleanCardBackground()
        .animation(.snappy(duration: 0.2), value: appState.isLocked)
        .animation(.snappy(duration: 0.2), value: blocker.isEscapeHeld)
    }

    private var statusTint: Color {
        if appState.isLocked { return .red }
        return appState.canAttemptLock ? .green : .orange
    }

    private var statusMessage: String {
        if appState.isLocked {
            return "Keyboard input is blocked"
        }
        if appState.canAttemptLock {
            return "Pointer input remains available"
        }
        return "Grant permission before locking"
    }
}

private struct PermissionCard: View {
    @ObservedObject var appState: KeyCleanState

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "hand.raised.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(.orange)

                Text("Permission required")
                    .font(.system(size: 13, weight: .bold))

                Spacer()
            }

            Text("KeyClean needs macOS permission before it can intercept keyboard input.")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.secondary)
                .lineLimit(2)

            HStack(spacing: 8) {
                Button("Accessibility") {
                    appState.requestAccessibility()
                    appState.openAccessibilitySettings()
                }
                .buttonStyle(KeyCleanPrimaryButtonStyle(tint: .orange))

                Button("Input") {
                    appState.requestInputMonitoring()
                    appState.openInputMonitoringSettings()
                }
                .buttonStyle(KeyCleanPrimaryButtonStyle(tint: .gray))
            }
        }
        .padding(12)
        .keyCleanCardBackground()
    }
}

private struct PermissionRow: View {
    let icon: String
    let title: String
    let subtitle: String
    let granted: Bool
    let actionTitle: String
    let action: () -> Void

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 8)

            if granted {
                StatusPill(title: "OK", tint: .green)
            } else {
                Button(actionTitle, action: action)
                    .font(.system(size: 10, weight: .bold))
                    .buttonStyle(.bordered)
                    .controlSize(.small)
            }
        }
        .padding(.vertical, 3)
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))

                Text(subtitle)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }

            Spacer()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 3)
    }
}

private struct MessageCard: View {
    let icon: String
    let title: String?
    let message: String
    let tint: Color
    var compact = false

    var body: some View {
        HStack(alignment: .center, spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: compact ? 12 : 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20)

            VStack(alignment: .leading, spacing: 3) {
                if let title {
                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                }

                Text(message)
                    .font(.system(size: compact ? 9.5 : 10.5, weight: .medium))
                    .foregroundStyle(compact ? tint.opacity(0.88) : .secondary)
                    .lineLimit(compact ? 1 : 2)
            }

            Spacer()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, compact ? 7 : 12)
        .background {
            RoundedRectangle(cornerRadius: 10)
                .fill(tint.opacity(compact ? 0.10 : 0.0))
                .overlay {
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(tint.opacity(compact ? 0.18 : 0.0), lineWidth: 0.5)
                }
        }
        .if(!compact) { view in
            view.keyCleanCardBackground()
        }
    }
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}
