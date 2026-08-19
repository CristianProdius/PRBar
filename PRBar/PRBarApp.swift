import AppKit
import Combine
import SwiftUI

@main
struct PRBarApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            Button("Settings…") {
                appDelegate.state.openSettings()
            }
            .keyboardShortcut(",", modifiers: .command)
            Button("Refresh") {
                Task { await appDelegate.state.refresh() }
            }
            .keyboardShortcut("r", modifiers: .command)
            Divider()
            Button("Quit PRBar") {
                appDelegate.state.quit()
            }
            .keyboardShortcut("q", modifiers: .command)
        } label: {
            MenuBarLabel(state: appDelegate.state)
        }
        .menuBarExtraStyle(.menu)
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
    private var onboardingWindow: NSWindow?
    private var settingsWindow: NSWindow?
    private var observers: Set<AnyCancellable> = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let panel = OverlayPanel(state: state)
        overlay = panel
        panel.applyVisibility(state.shouldShowHUD)

        Publishers.CombineLatest4(
            state.$hudVisible,
            state.$hideInFullscreen,
            state.$isFullscreenSpace,
            state.$hasCompletedOnboarding
        )
        .map { visible, hide, fullscreen, onboarded in
            onboarded && visible && !(hide && fullscreen)
        }
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

        state.$settingsTick
            .dropFirst()
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in
                self?.presentSettings()
            }
            .store(in: &observers)

        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            DispatchQueue.main.async {
                self?.revertToAccessoryIfIdle()
            }
        }

        if state.hasCompletedOnboarding {
            state.start()
        } else {
            presentOnboarding()
        }
    }

    func presentOnboarding() {
        if let onboardingWindow {
            showConfigWindow(onboardingWindow)
            return
        }
        let window = makeConfigWindow(
            title: "Welcome to PRBar",
            size: NSSize(width: 460, height: 700),
            transparentTitlebar: true
        )
        window.contentView = NSHostingView(
            rootView: OnboardingView(state: state) { [weak self] in
                self?.finishOnboarding()
            }
        )
        onboardingWindow = window
        showConfigWindow(window)
    }

    func presentSettings() {
        if let settingsWindow {
            showConfigWindow(settingsWindow)
            return
        }
        let window = makeConfigWindow(
            title: "PRBar Settings",
            size: NSSize(width: 440, height: 620),
            transparentTitlebar: false
        )
        window.styleMask.insert(.resizable)
        window.contentView = NSHostingView(rootView: SettingsView(state: state))
        settingsWindow = window
        showConfigWindow(window)
    }

    private func finishOnboarding() {
        onboardingWindow?.close()
        onboardingWindow = nil
        revertToAccessoryIfIdle()
    }

    private func showConfigWindow(_ window: NSWindow) {
        NSApp.setActivationPolicy(.regular)
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func makeConfigWindow(title: String, size: NSSize, transparentTitlebar: Bool) -> NSWindow {
        var style: NSWindow.StyleMask = [.titled, .closable]
        if transparentTitlebar {
            style.insert(.fullSizeContentView)
        }
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: style,
            backing: .buffered,
            defer: false
        )
        window.title = title
        window.titleVisibility = transparentTitlebar ? .hidden : .visible
        window.titlebarAppearsTransparent = transparentTitlebar
        window.isReleasedWhenClosed = false
        window.isMovableByWindowBackground = true
        window.level = .floating
        return window
    }

    private func revertToAccessoryIfIdle() {
        let configOpen = [onboardingWindow, settingsWindow].contains { window in
            window?.isVisible == true
        }
        if !configOpen {
            NSApp.setActivationPolicy(.accessory)
        }
    }
}
