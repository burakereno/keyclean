import AppKit
import CoreGraphics
import Foundation

@MainActor
final class KeyboardBlocker: ObservableObject {
    @Published private(set) var isEscapeHeld = false
    @Published private(set) var unlockProgress = 0.0

    var onUnlockRequested: (() -> Void)?
    var onError: ((String) -> Void)?
    private(set) var lastError: String?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var escapeTimer: Timer?
    private var escapeStartedAt: Date?

    private static let escapeKeyCode: Int64 = 53
    private let unlockHoldDuration: TimeInterval = 3.0
    private let timerInterval: TimeInterval = 0.04

    deinit {
        eventTap.map { CGEvent.tapEnable(tap: $0, enable: false) }
    }

    func start() -> Bool {
        stop()
        lastError = nil

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
            | CGEventMask(1 << CGEventType.keyUp.rawValue)
            | CGEventMask(1 << CGEventType.flagsChanged.rawValue)
            | CGEventMask(1 << 14)

        let observer = UnsafeMutableRawPointer(Unmanaged.passUnretained(self).toOpaque())
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: KeyboardBlocker.eventCallback,
            userInfo: observer
        ) else {
            lastError = "macOS refused the event tap. Check Accessibility or Input Monitoring permissions, then relaunch if needed."
            return false
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        if let runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CGEvent.tapEnable(tap: tap, enable: true)
        return true
    }

    func stop() {
        stopEscapeTimer(resetProgress: true)

        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }

        eventTap = nil
        runLoopSource = nil
    }

    func resetEmergencyState() {
        isEscapeHeld = false
        unlockProgress = 0
    }

    func validateEventTap() -> Bool {
        guard let eventTap else { return false }

        if !CGEvent.tapIsEnabled(tap: eventTap) {
            CGEvent.tapEnable(tap: eventTap, enable: true)
        }

        return CGEvent.tapIsEnabled(tap: eventTap)
    }

    private static let eventCallback: CGEventTapCallBack = { _, type, event, userInfo in
        guard let userInfo else { return nil }
        let blocker = Unmanaged<KeyboardBlocker>.fromOpaque(userInfo).takeUnretainedValue()

        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            Task { @MainActor in
                blocker.reenableTapIfNeeded()
            }
            return nil
        }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        if keyCode == KeyboardBlocker.escapeKeyCode, type == .keyDown || type == .keyUp {
            Task { @MainActor in
                blocker.handleEscapeEvent(type: type)
            }
        }

        return nil
    }

    private func handleEscapeEvent(type: CGEventType) {
        if type == .keyDown {
            startEscapeTimerIfNeeded()
        } else if type == .keyUp {
            stopEscapeTimer(resetProgress: true)
        }
    }

    private func reenableTapIfNeeded() {
        guard let eventTap else { return }
        CGEvent.tapEnable(tap: eventTap, enable: true)
    }

    private func startEscapeTimerIfNeeded() {
        guard escapeTimer == nil else { return }

        escapeStartedAt = Date()
        isEscapeHeld = true
        unlockProgress = 0

        escapeTimer = Timer.scheduledTimer(withTimeInterval: timerInterval, repeats: true) { [weak self] timer in
            Task { @MainActor in
                guard let self else {
                    timer.invalidate()
                    return
                }
                self.updateEscapeProgress()
            }
        }
    }

    private func updateEscapeProgress() {
        guard let escapeStartedAt else { return }

        let elapsed = Date().timeIntervalSince(escapeStartedAt)
        unlockProgress = min(1, elapsed / unlockHoldDuration)

        if elapsed >= unlockHoldDuration {
            stopEscapeTimer(resetProgress: false)
            onUnlockRequested?()
        }
    }

    private func stopEscapeTimer(resetProgress: Bool) {
        escapeTimer?.invalidate()
        escapeTimer = nil
        escapeStartedAt = nil
        isEscapeHeld = false

        if resetProgress {
            unlockProgress = 0
        }
    }
}
