import AppKit
import Combine
import SwiftUI

@main
struct PRBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MenuView(state: appDelegate.state)
        } label: {
            MenuBarLabel(state: appDelegate.state)
        }
        .menuBarExtraStyle(.window)
    }
}

private struct MenuBarLabel: View {
    @ObservedObject var state: AppState

    var body: some View {
        Label {
            Text(state.goalMet ? "\(state.count)" : "\(state.count)/\(state.goal)")
        } icon: {
            Image(systemName: state.goalMet ? "checkmark.circle.fill" : "chart.bar.fill")
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let state = AppState()
    private var overlay: OverlayPanel?
    private var observers: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let panel = OverlayPanel(state: state)
        overlay = panel
        panel.applyVisibility(state.shouldShowHUD)

        Publishers.CombineLatest3(
            state.$hudVisible,
            state.$hideInFullscreen,
            state.$isFullscreenSpace
        )
        .map { visible, hide, fullscreen in visible && !(hide && fullscreen) }
        .receive(on: DispatchQueue.main)
        .sink { [weak self] visible in
            self?.overlay?.applyVisibility(visible)
        }
        .store(in: &observers)

        state.$positionToken
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.overlay?.resetToMouseScreen()
            }
            .store(in: &observers)

        state.$overflowTick
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.overlay?.showOverflowMenu()
            }
            .store(in: &observers)

        state.start()
    }
}
