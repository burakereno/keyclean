import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private let appState: KeyCleanState
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var cancellables = Set<AnyCancellable>()
    private var symbolCache: [String: NSImage] = [:]
    private let symbolConfig = NSImage.SymbolConfiguration(pointSize: 13, weight: .medium)

    init(appState: KeyCleanState) {
        self.appState = appState
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        super.init()

        popover.behavior = .transient
        popover.animates = true
        popover.appearance = NSAppearance(named: .darkAqua)
        popover.contentSize = NSSize(width: 340, height: 286)
        popover.contentViewController = NSHostingController(
            rootView: StatusPanelView(appState: appState)
                .frame(width: 340, height: 286)
        )

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover(_:))
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        appState.$isLocked
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBarButton() }
            .store(in: &cancellables)

        appState.$permissionState
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateMenuBarButton() }
            .store(in: &cancellables)

        updateMenuBarButton()
    }

    @objc private func togglePopover(_ sender: NSStatusBarButton) {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            showContextMenu(from: sender)
            return
        }

        if popover.isShown {
            popover.performClose(sender)
        } else {
            appState.refreshPermissions()
            popover.show(relativeTo: sender.bounds, of: sender, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    private func showContextMenu(from button: NSStatusBarButton) {
        let menu = NSMenu()

        let toggleTitle = appState.isLocked ? "Unlock Keyboard" : "Lock Keyboard"
        let toggleItem = NSMenuItem(title: toggleTitle, action: #selector(toggleLockFromMenu), keyEquivalent: "")
        toggleItem.target = self
        toggleItem.isEnabled = true
        menu.addItem(toggleItem)

        let permissionsItem = NSMenuItem(title: "Open Permissions", action: #selector(openPermissions), keyEquivalent: "")
        permissionsItem.target = self
        menu.addItem(permissionsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit KeyClean", action: #selector(quit), keyEquivalent: "q")
        quitItem.keyEquivalentModifierMask = [.command]
        quitItem.target = self
        quitItem.isEnabled = !appState.isLocked
        menu.addItem(quitItem)

        menu.popUp(positioning: nil, at: NSPoint(x: button.bounds.midX, y: button.bounds.minY), in: button)
    }

    @objc private func toggleLockFromMenu() {
        appState.toggleLock()
    }

    @objc private func openPermissions() {
        PermissionManager.shared.openAccessibilitySettings()
    }

    @objc private func quit() {
        NSApp.terminate(nil)
    }

    private func updateMenuBarButton() {
        guard let button = statusItem.button else { return }

        let image = renderStatusImage()
        statusItem.length = image.size.width
        button.image = image
        button.image?.isTemplate = true
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone
        button.title = ""
        button.toolTip = appState.isLocked ? "KeyClean: keyboard locked" : "KeyClean: ready"
    }

    private func renderStatusImage() -> NSImage {
        let width = StatusBarMetrics.contentWidth
        let height = StatusBarMetrics.statusHeight
        let image = NSImage(size: NSSize(width: width, height: height))

        image.lockFocus()
        NSColor.clear.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()

        drawSymbol(
            appState.isLocked ? "lock.fill" : "lock.open.fill",
            x: StatusBarMetrics.horizontalPadding,
            canvasHeight: height
        )

        image.unlockFocus()
        image.isTemplate = true
        return image
    }

    private func drawSymbol(_ symbolName: String, x: CGFloat, canvasHeight: CGFloat) {
        let symbol: NSImage
        if let cached = symbolCache[symbolName] {
            symbol = cached
        } else if let image = NSImage(
            systemSymbolName: symbolName,
            accessibilityDescription: "KeyClean"
        )?.withSymbolConfiguration(symbolConfig) {
            symbolCache[symbolName] = image
            symbol = image
        } else {
            return
        }

        let size = symbol.size
        let rect = NSRect(
            x: x + (StatusBarMetrics.iconWidth - size.width) / 2,
            y: floor((canvasHeight - size.height) / 2),
            width: size.width,
            height: size.height
        )
        symbol.draw(in: rect)
    }
}

private enum StatusBarMetrics {
    static let statusHeight: CGFloat = 22
    static let horizontalPadding: CGFloat = 3
    static let iconWidth: CGFloat = 15
    static let contentWidth = ceil(horizontalPadding * 2 + iconWidth)
}
