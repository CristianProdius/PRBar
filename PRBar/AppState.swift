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
    @Published var isHovered = false
    @Published var justMerged = false
    @Published var streak: Int
    @Published var hudVisible: Bool {
        didSet { UserDefaults.standard.set(hudVisible, forKey: Keys.hudVisible) }
    }
    @Published var launchesAtLogin: Bool
    @Published var hudOrigin: CGPoint? {
        didSet {
            if let hudOrigin {
                UserDefaults.standard.set(hudOrigin.x, forKey: Keys.hudX)
                UserDefaults.standard.set(hudOrigin.y, forKey: Keys.hudY)
            }
        }
    }

    var count: Int { prs.count }
    var ratio: Double { ProgressMath.ratio(count: count, goal: goal) }
    var goalMet: Bool { count >= goal }

    private var client: GitHubClient
    private var pollTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var lastActiveDay: Date?
    private var pulseTask: Task<Void, Never>?

    init(client: GitHubClient = GitHubClient()) {
        let storedGoal = UserDefaults.standard.object(forKey: Keys.goal) as? Int ?? 50
        self.goal = ProgressMath.clampGoal(storedGoal)
        self.username = UserDefaults.standard.string(forKey: Keys.username) ?? ""
        self.hudVisible = UserDefaults.standard.object(forKey: Keys.hudVisible) as? Bool ?? true
        self.launchesAtLogin = SMAppService.mainApp.status == .enabled
        self.streak = UserDefaults.standard.integer(forKey: Keys.streak)
        if UserDefaults.standard.object(forKey: Keys.lastActiveDay) != nil {
            self.lastActiveDay = Date(timeIntervalSince1970: UserDefaults.standard.double(forKey: Keys.lastActiveDay))
        }
        if UserDefaults.standard.object(forKey: Keys.hudX) != nil {
            self.hudOrigin = CGPoint(
                x: UserDefaults.standard.double(forKey: Keys.hudX),
                y: UserDefaults.standard.double(forKey: Keys.hudY)
            )
        }
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
            let next = try await client.mergedPRs(author: username, window: window)
            let grew = next.count > prs.count && lastUpdated != nil
            prs = next
            lastError = nil
            lastUpdated = Date()
            persistStreak(hasMergeToday: !next.isEmpty)
            if grew {
                pulseMerge()
            }
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

    private func persistStreak(hasMergeToday: Bool) {
        let next = StreakMath.updated(
            current: .init(count: streak, lastActiveDay: lastActiveDay),
            hasMergeToday: hasMergeToday
        )
        streak = next.count
        lastActiveDay = next.lastActiveDay
        UserDefaults.standard.set(streak, forKey: Keys.streak)
        if let lastActiveDay {
            UserDefaults.standard.set(lastActiveDay.timeIntervalSince1970, forKey: Keys.lastActiveDay)
        }
    }

    private func pulseMerge() {
        pulseTask?.cancel()
        justMerged = true
        pulseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_600_000_000)
            guard !Task.isCancelled else { return }
            justMerged = false
        }
    }

    private enum Keys {
        static let goal = "prbar.goal"
        static let username = "prbar.username"
        static let hudVisible = "prbar.hudVisible"
        static let streak = "prbar.streak"
        static let lastActiveDay = "prbar.lastActiveDay"
        static let hudX = "prbar.hudX"
        static let hudY = "prbar.hudY"
    }
}
