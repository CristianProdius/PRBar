import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    @Published var goal: Int {
        didSet { UserDefaults.standard.set(goal, forKey: Keys.goal) }
    }
    @Published private(set) var prs: [MergedPR] = []
    @Published private(set) var username: String
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading = false
    @Published var isExpanded = false
    @Published var hudVisible: Bool {
        didSet { UserDefaults.standard.set(hudVisible, forKey: Keys.hudVisible) }
    }
    @Published var launchesAtLogin: Bool

    var count: Int { prs.count }
    var ratio: Double { ProgressMath.ratio(count: count, goal: goal) }
    var goalMet: Bool { count >= goal }

    private var client: GitHubClient
    private var pollTimer: Timer?
    private var wakeObserver: NSObjectProtocol?

    init(client: GitHubClient = GitHubClient()) {
        let storedGoal = UserDefaults.standard.object(forKey: Keys.goal) as? Int ?? 50
        self.goal = ProgressMath.clampGoal(storedGoal)
        self.username = UserDefaults.standard.string(forKey: Keys.username) ?? ""
        self.hudVisible = UserDefaults.standard.object(forKey: Keys.hudVisible) as? Bool ?? true
        self.launchesAtLogin = SMAppService.mainApp.status == .enabled
        self.client = client
    }

    func start() {
        Task { await refresh() }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 180, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        if let wakeObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(wakeObserver)
        }
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
    }

    func refresh() async {
        if isLoading { return }
        isLoading = true
        defer { isLoading = false }

        do {
            if username.isEmpty {
                let login = try await client.viewerLogin()
                username = login
                UserDefaults.standard.set(login, forKey: Keys.username)
            }
            let window = DayWindow.local()
            prs = try await client.mergedPRs(author: username, window: window)
            lastError = nil
            lastUpdated = Date()
        } catch {
            lastError = error.localizedDescription
        }
    }

    func setGoal(_ value: Int) {
        goal = ProgressMath.clampGoal(value)
    }

    func toggleLaunchAtLogin() {
        do {
            if launchesAtLogin {
                try SMAppService.mainApp.unregister()
            } else {
                try SMAppService.mainApp.register()
            }
            launchesAtLogin = SMAppService.mainApp.status == .enabled
        } catch {
            lastError = error.localizedDescription
        }
    }

    func open(_ pr: MergedPR) {
        NSWorkspace.shared.open(pr.url)
    }

    func quit() {
        NSApp.terminate(nil)
    }

    private enum Keys {
        static let goal = "prbar.goal"
        static let username = "prbar.username"
        static let hudVisible = "prbar.hudVisible"
    }
}
