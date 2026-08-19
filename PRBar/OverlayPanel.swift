import AppKit
import SwiftUI

final class OverlayPanel: NSPanel {
    private var hostingView: NSHostingView<OverlayView>?

    init(state: AppState) {
        let rect = NSRect(x: 0, y: 0, width: 328, height: 40)
        super.init(
            contentRect: rect,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )

        level = .statusBar
        isOpaque = false
        backgroundColor = .clear
        hasShadow = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        isMovableByWindowBackground = true
        hidesOnDeactivate = false
        animationBehavior = .utilityWindow

        let hosting = NSHostingView(rootView: OverlayView(state: state))
        hosting.translatesAutoresizingMaskIntoConstraints = true
        hosting.frame = rect
        hosting.autoresizingMask = [.width, .height]
        if #available(macOS 14.0, *) {
            hosting.sizingOptions = [.intrinsicContentSize]
        }
        contentView = hosting
        hostingView = hosting
        positionTopCenter()
    }

    func fitContent() {
        guard let hostingView else { return }
        hostingView.invalidateIntrinsicContentSize()
        hostingView.layoutSubtreeIfNeeded()
        var size = hostingView.fittingSize
        if size.width < 328 { size.width = 328 }
        if size.height < 40 { size.height = 40 }
        var next = frame
        let top = next.maxY
        next.size = size
        next.origin.y = top - size.height
        setFrame(next, display: true, animate: true)
    }

    func positionTopCenter() {
        guard let screen = NSScreen.main ?? NSScreen.screens.first else { return }
        let visible = screen.visibleFrame
        let size = frame.size
        let x = visible.midX - size.width / 2
        let y = visible.maxY - size.height - 8
        setFrameOrigin(NSPoint(x: x, y: y))
    }

    func applyVisibility(_ visible: Bool) {
        if visible {
            positionTopCenter()
            orderFrontRegardless()
        } else {
            orderOut(nil)
        }
    }

    override var canBecomeKey: Bool { false }
    override var canBecomeMain: Bool { false }
}
