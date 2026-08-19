import AppKit
import CoreGraphics
import SwiftUI

final class ClearHostingView<Content: View>: NSHostingView<Content> {
    override var isOpaque: Bool { false }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        makeClear()
    }

    override func layout() {
        super.layout()
        makeClear()
    }

    private func makeClear() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.clear.cgColor
        layer?.isOpaque = false
        window?.isOpaque = false
        window?.backgroundColor = .clear
    }
}

final class OverlayPanel: NSPanel {
    static let cardWidth: CGFloat = 380
    static let compactSize = NSSize(width: 380, height: 36)
    static let expandedSize = NSSize(width: 380, height: 292)

    private var hostingView: ClearHostingView<OverlayView>?
    private let state: AppState
    private var collapseTask: Task<Void, Never>?

    init(state: AppState) {
        self.state = state
        let rect = NSRect(origin: .zero, size: Self.compactSize)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        becomesKeyOnlyIfNeeded = true
        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        titleVisibility = .hidden
        titlebarAppearsTransparent = true
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        isMovableByWindowBackground = false
        level = NSWindow.Level(rawValue: NSWindow.Level.statusBar.rawValue + 2)
        hidesOnDeactivate = false
        animationBehavior = .none
        setContentSize(Self.compactSize)

        let hosting = ClearHostingView(rootView: OverlayView(state: state))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.isOpaque = false
        if #available(macOS 14.0, *) {
            hosting.sizingOptions = []
        }
        hosting.frame = rect
        hosting.autoresizingMask = [.width, .height]
        contentView = hosting
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView = hosting
        pinToNotch(expanded: false)
        refreshTracking()
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            guard let self else { return }
            self.pinToNotch(expanded: self.state.isHovered || self.state.menuOpen)
        }
    }

    func applyCardSize(expanded: Bool) {
        pinToNotch(expanded: expanded)
        refreshTracking()
    }

    func restorePosition() {
        pinToNotch(expanded: state.isHovered || state.menuOpen)
    }

    func pinToNotch(expanded: Bool) {
        let size = expanded ? Self.expandedSize : Self.compactSize
        let screen = Self.notchScreen()
        let origin = NotchLayout.origin(screenFrame: screen.frame, size: size)
        setFrame(NSRect(origin: origin, size: size), display: true, animate: false)
        hostingView?.frame = NSRect(origin: .zero, size: size)
    }

    func showOverflowMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            item.target = self
            return item
        }

        menu.addItem(item("Settings…", #selector(overflowSettings), key: ","))
        menu.addItem(item("Refresh", #selector(overflowRefresh), key: "r"))
        menu.addItem(item("Snap to notch", #selector(overflowBring)))
        menu.addItem(.separator())
        menu.addItem(item(state.hudVisible ? "Hide on-screen bar" : "Show on-screen bar", #selector(overflowToggleBar)))

        let sound = item("Sound on merge", #selector(overflowToggleSound))
        sound.state = state.soundEnabled ? .on : .off
        menu.addItem(sound)

        let fullscreen = item("Hide on fullscreen spaces", #selector(overflowToggleFullscreen))
        fullscreen.state = state.hideInFullscreen ? .on : .off
        menu.addItem(fullscreen)

        menu.addItem(.separator())
        menu.addItem(item("Quit PRBar", #selector(overflowQuit), key: "q"))

        menu.popUp(positioning: nil, at: mousePointInHostingView(), in: hostingView)
        state.menuOpen = false
        applyCardSize(expanded: state.isHovered)
        updateHoverFromMouse()
    }

    @objc private func overflowSettings() { state.openSettings() }
    @objc private func overflowRefresh() { Task { await state.refresh() } }
    @objc private func overflowBring() { resetToMouseScreen() }
    @objc private func overflowToggleBar() { state.hudVisible.toggle() }
    @objc private func overflowToggleSound() { state.soundEnabled.toggle() }
    @objc private func overflowToggleFullscreen() { state.hideInFullscreen.toggle() }
    @objc private func overflowQuit() { state.quit() }

    private func mousePointInHostingView() -> NSPoint {
        guard let hostingView else { return NSPoint(x: 360, y: 24) }
        return hostingView.convert(mouseLocationOutsideOfEventStream, from: nil)
    }

    func resetToMouseScreen() {
        state.hudOrigin = nil
        pinToNotch(expanded: state.isHovered || state.menuOpen)
        orderFrontRegardless()
    }

    func applyVisibility(_ visible: Bool) {
        if visible {
            pinToNotch(expanded: state.isHovered || state.menuOpen)
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    static func notchScreen() -> NSScreen {
        let builtin = NSScreen.screens.first { screen in
            let id = screen.displayID
            return CGDisplayIsBuiltin(id) != 0 && CGDisplayIsOnline(id) != 0
        }
        if let builtin { return builtin }
        if let notched = NSScreen.screens.first(where: { $0.safeAreaInsets.top > 16 }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens[0]
    }

    private func updateHoverFromMouse() {
        let point = mousePointInHostingView()
        let hit = hostingView?.bounds.insetBy(dx: -6, dy: -6) ?? NSRect(origin: .zero, size: frame.size)
        let inside = hit.contains(point)
        if inside {
            collapseTask?.cancel()
            if !state.isHovered {
                state.isHovered = true
                applyCardSize(expanded: true)
            }
        } else if !state.menuOpen {
            scheduleCollapse()
        }
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 220_000_000)
            guard let self, !Task.isCancelled, !self.state.menuOpen else { return }
            let point = self.mousePointInHostingView()
            let hit = self.hostingView?.bounds.insetBy(dx: -6, dy: -6) ?? NSRect(origin: .zero, size: self.frame.size)
            if hit.contains(point) { return }
            self.state.isHovered = false
            self.applyCardSize(expanded: false)
        }
    }

    private func refreshTracking() {
        guard let hostingView else { return }
        hostingView.trackingAreas.forEach { hostingView.removeTrackingArea($0) }
        hostingView.addTrackingArea(
            NSTrackingArea(
                rect: hostingView.bounds,
                options: [.mouseEnteredAndExited, .mouseMoved, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) { updateHoverFromMouse() }
    override func mouseMoved(with event: NSEvent) { updateHoverFromMouse() }
    override func mouseExited(with event: NSEvent) {
        if !state.menuOpen { scheduleCollapse() }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        pinToNotch(expanded: state.isHovered || state.menuOpen)
    }
}

private extension NSScreen {
    var displayID: CGDirectDisplayID {
        let key = NSDeviceDescriptionKey("NSScreenNumber")
        return deviceDescription[key] as? CGDirectDisplayID ?? 0
    }
}
