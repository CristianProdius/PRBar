import AppKit
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
    static let panelSize = NSSize(width: 400, height: 280)

    private var hostingView: ClearHostingView<OverlayView>?
    private let state: AppState
    private var collapseTask: Task<Void, Never>?

    init(state: AppState) {
        self.state = state
        let rect = NSRect(origin: .zero, size: Self.panelSize)
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
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .none
        setContentSize(Self.panelSize)

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
        restorePosition()
        refreshTracking()
    }

    func fitContent() {
        setContentSize(Self.panelSize)
        hostingView?.frame = NSRect(origin: .zero, size: Self.panelSize)
        refreshTracking()
    }

    func restorePosition() {
        if let saved = state.hudOrigin, isOnAnyScreen(saved) {
            setFrameOrigin(saved)
            return
        }
        centerOnMouseScreen()
    }

    func showOverflowMenu() {
        let menu = NSMenu()
        menu.autoenablesItems = false

        func item(_ title: String, _ sel: Selector, key: String = "") -> NSMenuItem {
            let item = NSMenuItem(title: title, action: sel, keyEquivalent: key)
            item.target = self
            return item
        }

        menu.addItem(item("Refresh", #selector(overflowRefresh), key: "r"))
        menu.addItem(item("Bring bar here", #selector(overflowBring)))
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
        updateHoverFromMouse()
    }

    @objc private func overflowRefresh() { Task { await state.refresh() } }
    @objc private func overflowBring() { resetToMouseScreen() }
    @objc private func overflowToggleBar() { state.hudVisible.toggle() }
    @objc private func overflowToggleSound() { state.soundEnabled.toggle() }
    @objc private func overflowToggleFullscreen() { state.hideInFullscreen.toggle() }
    @objc private func overflowQuit() { state.quit() }

    private func mousePointInHostingView() -> NSPoint {
        guard let hostingView else { return NSPoint(x: 376, y: 260) }
        return hostingView.convert(mouseLocationOutsideOfEventStream, from: nil)
    }

    func resetToMouseScreen() {
        state.hudOrigin = nil
        centerOnMouseScreen()
        orderFrontRegardless()
    }

    func applyVisibility(_ visible: Bool) {
        if visible {
            restorePosition()
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    private func centerOnMouseScreen() {
        let screen = Self.screenUnderMouse()
        let visible = screen.visibleFrame
        let x = visible.midX - Self.panelSize.width / 2
        let y = visible.maxY - Self.panelSize.height - 8
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func isOnAnyScreen(_ origin: CGPoint) -> Bool {
        let probe = NSRect(origin: origin, size: NSSize(width: 80, height: 28))
        return NSScreen.screens.contains { $0.visibleFrame.intersects(probe) }
    }

    static func screenUnderMouse() -> NSScreen {
        let point = NSEvent.mouseLocation
        return NSScreen.screens.first { $0.frame.contains(point) }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }

    private func cardRect() -> NSRect {
        let height: CGFloat = (state.isHovered || state.menuOpen) ? 268 : 52
        return NSRect(x: 0, y: Self.panelSize.height - height, width: Self.panelSize.width, height: height)
    }

    private func updateHoverFromMouse() {
        let point = mousePointInHostingView()
        let inside = cardRect().insetBy(dx: -4, dy: -4).contains(point)
        if inside {
            collapseTask?.cancel()
            if !state.isHovered { state.isHovered = true }
        } else if !state.menuOpen {
            scheduleCollapse()
        }
    }

    private func scheduleCollapse() {
        collapseTask?.cancel()
        collapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 180_000_000)
            guard let self, !Task.isCancelled, !self.state.menuOpen else { return }
            let point = self.mousePointInHostingView()
            if self.cardRect().insetBy(dx: -4, dy: -4).contains(point) { return }
            self.state.isHovered = false
            self.state.isExpanded = false
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

    override func mouseEntered(with event: NSEvent) {
        updateHoverFromMouse()
    }

    override func mouseMoved(with event: NSEvent) {
        updateHoverFromMouse()
    }

    override func mouseExited(with event: NSEvent) {
        if !state.menuOpen {
            scheduleCollapse()
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        if isOnAnyScreen(frame.origin) {
            state.hudOrigin = frame.origin
        }
    }
}
