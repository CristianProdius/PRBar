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
    @Published private(set) var openPRs: [MergedPR] = []
    @Published private(set) var rivalPRs: [MergedPR] = []
    @Published private(set) var weekDays: [WeekDay] = WeekMath.days(prs: [])
    @Published private(set) var username: String
    @Published private(set) var rivalUsername: String
    @Published var rivalDraft: String
    @Published private(set) var lastUpdated: Date?
    @Published private(set) var lastError: String?
    @Published private(set) var isLoading = false
    @Published var isExpanded = false
    @Published var isHovered = false
    @Published var menuOpen = false
    @Published var overflowTick = 0
    @Published var justMerged = false
    @Published var celebrating = false
    @Published var whisperTitle: String?
    @Published var streak: Int
    @Published var isFullscreenSpace = false
    @Published var positionToken = 0
    @Published var hudVisible: Bool {
        didSet { UserDefaults.standard.set(hudVisible, forKey: Keys.hudVisible) }
    }
    @Published var hideInFullscreen: Bool {
        didSet { UserDefaults.standard.set(hideInFullscreen, forKey: Keys.hideInFullscreen) }
    }
    @Published var soundEnabled: Bool {
        didSet { UserDefaults.standard.set(soundEnabled, forKey: Keys.soundEnabled) }
    }
    @Published var launchesAtLogin: Bool
    @Published var hudOrigin: CGPoint? {
        didSet {
            if let hudOrigin {
                UserDefaults.standard.set(hudOrigin.x, forKey: Keys.hudX)
                UserDefaults.standard.set(hudOrigin.y, forKey: Keys.hudY)
            } else {
                UserDefaults.standard.removeObject(forKey: Keys.hudX)
                UserDefaults.standard.removeObject(forKey: Keys.hudY)
            }
        }
    }
    @Published var hasCompletedOnboarding: Bool {
        didSet { UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.onboarded) }
    }
    @Published var githubStatus: GitHubAuthState = .idle
    @Published var settingsTick = 0

    var count: Int { prs.count }
    var rivalCount: Int { rivalPRs.count }
    var ratio: Double { ProgressMath.ratio(count: count, goal: goal) }
    var rivalRatio: Double { ProgressMath.ratio(count: rivalCount, goal: goal) }
    var goalMet: Bool { count >= goal }
    var raceHeadline: String { RivalMath.headline(you: count, them: rivalCount, rival: rivalUsername) }
    var paceMood: PaceMood { MoodMath.pace(count: count, goal: goal, now: Date()) }
    var raceMood: RaceMood { MoodMath.race(you: count, them: rivalCount, hasRival: !rivalUsername.isEmpty) }
    var moodLine: String {
        MoodMath.statusLine(pace: paceMood, race: raceMood, remaining: max(0, goal - count), rival: rivalUsername)
    }
    var shouldShowHUD: Bool {
        hasCompletedOnboarding && hudVisible && !(hideInFullscreen && isFullscreenSpace)
    }

    private var client: GitHubClient
    private var pollTimer: Timer?
    private var fullscreenTimer: Timer?
    private var wakeObserver: NSObjectProtocol?
    private var spaceObserver: NSObjectProtocol?
    private var lastActiveDay: Date?
    private var pulseTask: Task<Void, Never>?
    private var didStart = false

    init(client: GitHubClient = GitHubClient()) {
        let storedGoal = UserDefaults.standard.object(forKey: Keys.goal) as? Int ?? 50
        let storedUsername = UserDefaults.standard.string(forKey: Keys.username) ?? ""
        let storedRival = RivalMath.cleaned(UserDefaults.standard.string(forKey: Keys.rival) ?? "")
        let storedOnboarded: Bool
        if UserDefaults.standard.object(forKey: Keys.onboarded) != nil {
            storedOnboarded = UserDefaults.standard.bool(forKey: Keys.onboarded)
        } else {
            // Existing installs already resolved a GitHub login.
            storedOnboarded = !storedUsername.isEmpty
            UserDefaults.standard.set(storedOnboarded, forKey: Keys.onboarded)
        }
        self.goal = ProgressMath.clampGoal(storedGoal)
        self.username = storedUsername
        self.rivalUsername = storedRival
        self.rivalDraft = storedRival
        self.hudVisible = UserDefaults.standard.object(forKey: Keys.hudVisible) as? Bool ?? true
        self.hideInFullscreen = UserDefaults.standard.bool(forKey: Keys.hideInFullscreen)
        self.soundEnabled = UserDefaults.standard.bool(forKey: Keys.soundEnabled)
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
        self.hasCompletedOnboarding = storedOnboarded
        self.githubStatus = storedUsername.isEmpty ? .idle : .signedIn(storedUsername)
        self.client = client
    }

    func start() {
        guard !didStart else {
            Task { await refresh() }
            return
        }
        didStart = true
        Task { await refresh() }
        pollTimer?.invalidate()
        pollTimer = Timer.scheduledTimer(withTimeInterval: 45, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.refresh() }
        }
        observeWorkspace()
        refreshFullscreenFlag()
        fullscreenTimer?.invalidate()
        fullscreenTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshFullscreenFlag() }
        }
    }

    func refresh() async {
        isLoading = true
        defer { isLoading = false }

        do {
            if username.isEmpty {
                let login = try await client.viewerLogin()
                username = login
                UserDefaults.standard.set(login, forKey: Keys.username)
            }
            let week = DayWindow.lastSevenDays()
            async let weekPRsTask = client.mergedPRs(author: username, window: week)
            async let openTask = client.openPRs(author: username)
            let weekPRs = try await weekPRsTask
            let open = try await openTask
            let today = DayWindow.local()
            let next = weekPRs.filter { today.contains($0.mergedAt) }
            let grew = next.count > prs.count && lastUpdated != nil
            let crossedGoal = lastUpdated != nil && prs.count < goal && next.count >= goal
            prs = next
            openPRs = Array(open.prefix(8))
            weekDays = WeekMath.days(prs: weekPRs)
            lastError = nil
            lastUpdated = Date()
            persistStreak(hasMergeToday: !next.isEmpty)
            if grew {
                pulseMerge(latestTitle: next.first?.title, reachedGoal: crossedGoal)
            }
        } catch {
            lastError = error.localizedDescription
        }

        let rival = RivalMath.cleaned(rivalUsername)
        guard !rival.isEmpty else {
            rivalPRs = []
            return
        }
        do {
            let rivalWeek = try await client.mergedPRs(author: rival, window: DayWindow.lastSevenDays())
            rivalPRs = rivalWeek.filter { DayWindow.local().contains($0.mergedAt) }
        } catch {
            // Keep last rival score; don't fail your own board.
        }
    }

    func setGoal(_ value: Int) {
        goal = ProgressMath.clampGoal(value)
    }

    func resetBarPosition() {
        hudOrigin = nil
        hudVisible = true
        isExpanded = false
        positionToken += 1
    }

    func requestOverflowMenu() {
        menuOpen = true
        overflowTick += 1
    }

    func openSettings() {
        settingsTick += 1
    }

    func completeOnboarding(goal: Int, rival: String) {
        setGoal(goal)
        let cleaned = RivalMath.cleaned(rival)
        rivalUsername = cleaned
        rivalDraft = cleaned
        UserDefaults.standard.set(cleaned, forKey: Keys.rival)
        hasCompletedOnboarding = true
        hudVisible = true
        start()
    }

    func probeGitHub() async {
        githubStatus = .checking
        do {
            let login = try await client.viewerLogin()
            username = login
            UserDefaults.standard.set(login, forKey: Keys.username)
            githubStatus = .signedIn(login)
        } catch let error as GitHubClientError {
            switch error {
            case .ghNotFound: githubStatus = .missingCLI
            case .tokenMissing: githubStatus = .notSignedIn
            default: githubStatus = .failed(error.localizedDescription)
            }
        } catch {
            githubStatus = .failed(error.localizedDescription)
        }
    }

    func userExists(_ login: String) async throws -> Bool {
        try await client.userExists(login: login)
    }

    func setRival(_ raw: String) {
        let cleaned = RivalMath.cleaned(raw)
        rivalUsername = cleaned
        rivalDraft = cleaned
        UserDefaults.standard.set(cleaned, forKey: Keys.rival)
        Task { await refresh() }
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

    func refreshFullscreenFlag() {
        isFullscreenSpace = FullscreenDetect.isActive()
    }

    private func observeWorkspace() {
        let center = NSWorkspace.shared.notificationCenter
        if let wakeObserver {
            center.removeObserver(wakeObserver)
        }
        wakeObserver = center.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshFullscreenFlag()
                await self?.refresh()
            }
        }
        if let spaceObserver {
            center.removeObserver(spaceObserver)
        }
        spaceObserver = center.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in self?.refreshFullscreenFlag() }
        }
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

    private func pulseMerge(latestTitle: String?, reachedGoal: Bool) {
        pulseTask?.cancel()
        justMerged = true
        celebrating = reachedGoal
        whisperTitle = latestTitle
        if soundEnabled {
            if reachedGoal {
                MergeSound.playGoal()
            } else {
                MergeSound.playTick()
            }
        }
        pulseTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            justMerged = false
            celebrating = false
            whisperTitle = nil
        }
    }

    private enum Keys {
        static let goal = "prbar.goal"
        static let username = "prbar.username"
        static let hudVisible = "prbar.hudVisible"
        static let hideInFullscreen = "prbar.hideInFullscreen"
        static let soundEnabled = "prbar.soundEnabled"
        static let streak = "prbar.streak"
        static let lastActiveDay = "prbar.lastActiveDay"
        static let hudX = "prbar.hudX"
        static let hudY = "prbar.hudY"
        static let rival = "prbar.rival"
        static let onboarded = "prbar.onboarded"
    }
}

enum GitHubAuthState: Equatable {
    case idle
    case checking
    case signedIn(String)
    case missingCLI
    case notSignedIn
    case failed(String)

    var isSignedIn: Bool {
        if case .signedIn = self { return true }
        return false
    }

    var isChecking: Bool {
        if case .checking = self { return true }
        return false
    }
}
