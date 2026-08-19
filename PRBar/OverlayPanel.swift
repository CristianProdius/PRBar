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
    private var hostingView: ClearHostingView<OverlayView>?
    private let state: AppState
    private var collapseTask: Task<Void, Never>?

    init(state: AppState) {
        self.state = state
        let rect = NSRect(x: 0, y: 0, width: 168, height: 36)
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
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .none

        let hosting = ClearHostingView(rootView: OverlayView(state: state))
        hosting.wantsLayer = true
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        hosting.layer?.isOpaque = false
        if #available(macOS 14.0, *) {
            hosting.sizingOptions = [.intrinsicContentSize]
        }
        contentView = hosting
        contentView?.wantsLayer = true
        contentView?.layer?.backgroundColor = NSColor.clear.cgColor
        hostingView = hosting
        restorePosition()
        fitContent()
        refreshTracking()
    }

    func fitContent() {
        guard let hostingView else { return }
        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()
        var size = hostingView.fittingSize
        size.width = max(120, ceil(size.width) + 2)
        size.height = max(34, ceil(size.height) + 2)
        var next = frame
        let top = next.maxY
        next.size = size
        next.origin.y = top - size.height
        setFrame(next, display: true, animate: false)
        hostingView.frame = NSRect(origin: .zero, size: size)
        refreshTracking()
    }

    func restorePosition() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        if let saved = state.hudOrigin, visible.insetBy(dx: 40, dy: 20).contains(saved) {
            setFrameOrigin(saved)
            return
        }
        let size = frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - 10
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func applyVisibility(_ visible: Bool) {
        if visible {
            restorePosition()
            fitContent()
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }

    private func refreshTracking() {
        guard let hostingView else { return }
        hostingView.trackingAreas.forEach { hostingView.removeTrackingArea($0) }
        hostingView.addTrackingArea(
            NSTrackingArea(
                rect: hostingView.bounds,
                options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
                owner: self,
                userInfo: nil
            )
        )
    }

    override func mouseEntered(with event: NSEvent) {
        collapseTask?.cancel()
        state.isHovered = true
        fitContent()
    }

    override func mouseExited(with event: NSEvent) {
        state.isHovered = false
        collapseTask?.cancel()
        collapseTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: 280_000_000)
            guard let self, !Task.isCancelled, !self.state.isHovered else { return }
            withAnimation(.snappy(duration: 0.2)) {
                self.state.isExpanded = false
            }
            self.fitContent()
        }
    }

    override func mouseUp(with event: NSEvent) {
        super.mouseUp(with: event)
        state.hudOrigin = frame.origin
    }
}
