import Foundation

struct DayWindow: Equatable, Sendable {
    let start: Date
    let end: Date

    func contains(_ date: Date) -> Bool {
        date >= start && date < end
    }

    static func lastSevenDays(now: Date = Date(), calendar: Calendar = .current) -> DayWindow {
        let today = calendar.startOfDay(for: now)
        let start = calendar.date(byAdding: .day, value: -6, to: today) ?? today.addingTimeInterval(-6 * 86_400)
        let end = calendar.date(byAdding: .day, value: 1, to: today) ?? today.addingTimeInterval(86_400)
        return DayWindow(start: start, end: end)
    }

    static func local(now: Date = Date(), calendar: Calendar = .current) -> DayWindow {
        let start = calendar.startOfDay(for: now)
        let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
        return DayWindow(start: start, end: end)
    }

    /// GitHub `merged:` is date-precision and UTC. Search from the UTC day
    /// before local midnight so timezone edges are not dropped; filter locally.
    var githubSearchLowerBound: String {
        let utc = Calendar(identifier: .gregorian).date(byAdding: .day, value: -1, to: start) ?? start.addingTimeInterval(-86_400)
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: utc)
    }
}

struct MergedPR: Identifiable, Equatable, Sendable {
    let title: String
    let url: URL
    let repo: String
    let mergedAt: Date

    var id: String { url.absoluteString }
}

enum ProgressMath {
    static func ratio(count: Int, goal: Int) -> Double {
        guard goal > 0 else { return 0 }
        return min(1, Double(max(0, count)) / Double(goal))
    }

    static func clampGoal(_ value: Int) -> Int {
        min(500, max(1, value))
    }
}

enum StreakMath {
    struct Snapshot: Equatable {
        var count: Int
        var lastActiveDay: Date?
    }

    static func updated(
        current: Snapshot,
        hasMergeToday: Bool,
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> Snapshot {
        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today) ?? today.addingTimeInterval(-86_400)

        if hasMergeToday {
            if current.lastActiveDay == today { return current }
            if current.lastActiveDay == yesterday {
                return Snapshot(count: current.count + 1, lastActiveDay: today)
            }
            return Snapshot(count: 1, lastActiveDay: today)
        }

        if let last = current.lastActiveDay, last < yesterday {
            return Snapshot(count: 0, lastActiveDay: last)
        }
        return current
    }
}

struct WeekDay: Equatable, Identifiable, Sendable {
    let start: Date
    let count: Int
    let isToday: Bool
    let label: String

    var id: Date { start }
}

enum WeekMath {
    static let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    static func days(
        prs: [MergedPR],
        now: Date = Date(),
        calendar: Calendar = .current
    ) -> [WeekDay] {
        let today = calendar.startOfDay(for: now)
        return (0..<7).map { offset in
            let start = calendar.date(byAdding: .day, value: offset - 6, to: today) ?? today
            let end = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86_400)
            let count = prs.filter { $0.mergedAt >= start && $0.mergedAt < end }.count
            let weekday = calendar.component(.weekday, from: start)
            let label = weekdayLabels[(weekday - 1 + 7) % 7]
            return WeekDay(start: start, count: count, isToday: start == today, label: label)
        }
    }
}

enum PaceMood: String, Equatable, Sendable {
    case done, ahead, onTrack, danger, critical
}

enum RaceMood: String, Equatable, Sendable {
    case none, winning, tied, losing
}

enum MoodMath {
    static let workStartHour = 8
    static let workHours = 16.0

    static func expected(goal: Int, now: Date, calendar: Calendar = .current) -> Double {
        let start = calendar.startOfDay(for: now)
        let workStart = calendar.date(bySettingHour: workStartHour, minute: 0, second: 0, of: now)
            ?? start.addingTimeInterval(Double(workStartHour) * 3600)
        if now <= workStart { return 0 }
        let elapsed = now.timeIntervalSince(workStart)
        return Double(max(0, goal)) * min(1, elapsed / (workHours * 3600))
    }

    static func pace(count: Int, goal: Int, now: Date, calendar: Calendar = .current) -> PaceMood {
        if count >= goal { return .done }
        let needed = expected(goal: goal, now: now, calendar: calendar)
        if needed < 3 {
            return count > 0 ? .ahead : .onTrack
        }
        let ratio = Double(count) / needed
        if ratio >= 1.05 { return .ahead }
        if ratio >= 0.75 { return .onTrack }
        if ratio >= 0.45 { return .danger }
        return .critical
    }

    static func race(you: Int, them: Int, hasRival: Bool) -> RaceMood {
        guard hasRival else { return .none }
        if you > them { return .winning }
        if you < them { return .losing }
        return .tied
    }

    static func statusLine(pace: PaceMood, race: RaceMood, remaining: Int, rival: String) -> String {
        switch pace {
        case .done:
            return race == .losing ? "Goal hit — still chasing @\(rival)" : "Goal hit"
        case .critical:
            if race == .losing { return "Behind pace and losing. Go." }
            return "Danger — \(remaining) more or you miss the goal"
        case .danger:
            if race == .losing { return "Off pace and trailing @\(rival)" }
            return "Off pace — \(remaining) still to go"
        case .ahead:
            if race == .winning { return "Cooking. You’re up on @\(rival)" }
            if race == .losing { return "On pace, but @\(rival) is ahead" }
            return "Ahead of pace"
        case .onTrack:
            if race == .losing { return "On pace, trailing @\(rival)" }
            if race == .winning { return "On pace and leading" }
            return "On pace"
        }
    }
}

enum RivalMath {
    static func cleaned(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: CharacterSet(charactersIn: "@"))
        let allowed = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "-"))
        return String(trimmed.unicodeScalars.filter { allowed.contains($0) })
    }

    static func headline(you: Int, them: Int, rival: String) -> String {
        if rival.isEmpty { return "Add a rival to race today" }
        if you > them { return "You’re up \(you - them) on @\(rival)" }
        if them > you { return "@\(rival) is up \(them - you). Hunt." }
        return "Dead heat with @\(rival)"
    }
}

enum NotchLayout {
    static func origin(screenFrame: CGRect, size: CGSize) -> CGPoint {
        CGPoint(
            x: screenFrame.midX - size.width / 2,
            y: screenFrame.maxY - size.height
        )
    }
}

enum DateDecoding {
    static func iso8601(_ string: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: string) { return date }
        let basic = ISO8601DateFormatter()
        basic.formatOptions = [.withInternetDateTime]
        return basic.date(from: string)
    }
}
