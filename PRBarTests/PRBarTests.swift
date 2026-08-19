import XCTest

final class DayWindowTests: XCTestCase {
    func testLocalDayContainsNoonAndExcludesNextMidnight() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        let noon = date(2026, 8, 19, 12, 0, calendar: calendar)
        let window = DayWindow.local(now: noon, calendar: calendar)

        XCTAssertTrue(window.contains(date(2026, 8, 19, 0, 0, calendar: calendar)))
        XCTAssertTrue(window.contains(date(2026, 8, 19, 23, 59, calendar: calendar)))
        XCTAssertFalse(window.contains(date(2026, 8, 20, 0, 0, calendar: calendar)))
        XCTAssertFalse(window.contains(date(2026, 8, 18, 23, 59, calendar: calendar)))
    }

    func testGitHubSearchLowerBoundIsUTCDayBeforeLocalStart() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 3 * 3600)!
        let window = DayWindow.local(now: date(2026, 8, 19, 10, 0, calendar: calendar), calendar: calendar)
        // Local midnight Aug 19 00:00 +03 = Aug 18 21:00 UTC; minus one day for the bound.
        XCTAssertEqual(window.githubSearchLowerBound, "2026-08-17")
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
}

final class ProgressMathTests: XCTestCase {
    func testRatioClampsAndProtectsZeroGoal() {
        XCTAssertEqual(ProgressMath.ratio(count: 0, goal: 50), 0)
        XCTAssertEqual(ProgressMath.ratio(count: 25, goal: 50), 0.5)
        XCTAssertEqual(ProgressMath.ratio(count: 80, goal: 50), 1)
        XCTAssertEqual(ProgressMath.ratio(count: 10, goal: 0), 0)
    }

    func testClampGoal() {
        XCTAssertEqual(ProgressMath.clampGoal(0), 1)
        XCTAssertEqual(ProgressMath.clampGoal(50), 50)
        XCTAssertEqual(ProgressMath.clampGoal(900), 500)
    }
}

final class DateDecodingTests: XCTestCase {
    func testISO8601WithAndWithoutFractionalSeconds() {
        XCTAssertNotNil(DateDecoding.iso8601("2026-08-19T09:11:00Z"))
        XCTAssertNotNil(DateDecoding.iso8601("2026-08-19T09:11:00.123Z"))
        XCTAssertNil(DateDecoding.iso8601("not-a-date"))
    }
}

final class StreakMathTests: XCTestCase {
    func testFirstMergeStartsStreak() {
        let today = date(2026, 8, 19)
        let next = StreakMath.updated(
            current: .init(count: 0, lastActiveDay: nil),
            hasMergeToday: true,
            now: today,
            calendar: utc
        )
        XCTAssertEqual(next.count, 1)
        XCTAssertEqual(next.lastActiveDay, utc.startOfDay(for: today))
    }

    func testConsecutiveDayIncrements() {
        var calendar = utc
        let yesterday = date(2026, 8, 18)
        let today = date(2026, 8, 19)
        let next = StreakMath.updated(
            current: .init(count: 4, lastActiveDay: calendar.startOfDay(for: yesterday)),
            hasMergeToday: true,
            now: today,
            calendar: calendar
        )
        XCTAssertEqual(next.count, 5)
    }

    func testMissedDayResetsOnNextMerge() {
        let next = StreakMath.updated(
            current: .init(count: 6, lastActiveDay: utc.startOfDay(for: date(2026, 8, 16))),
            hasMergeToday: true,
            now: date(2026, 8, 19),
            calendar: utc
        )
        XCTAssertEqual(next.count, 1)
    }

    func testMidDayWithoutMergeKeepsStreak() {
        let next = StreakMath.updated(
            current: .init(count: 3, lastActiveDay: utc.startOfDay(for: date(2026, 8, 18))),
            hasMergeToday: false,
            now: date(2026, 8, 19, 10),
            calendar: utc
        )
        XCTAssertEqual(next.count, 3)
    }

    func testTwoDayGapClearsStreak() {
        let next = StreakMath.updated(
            current: .init(count: 3, lastActiveDay: utc.startOfDay(for: date(2026, 8, 16))),
            hasMergeToday: false,
            now: date(2026, 8, 19),
            calendar: utc
        )
        XCTAssertEqual(next.count, 0)
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }
}

final class WeekMathTests: XCTestCase {
    func testBucketsLastSevenDaysWithTodayOnTheRight() {
        let calendar = utc
        let today = date(2026, 8, 19, 15)
        let prs = [
            MergedPR(title: "a", url: URL(string: "https://e/1")!, repo: "o/a", mergedAt: date(2026, 8, 19, 8)),
            MergedPR(title: "b", url: URL(string: "https://e/2")!, repo: "o/a", mergedAt: date(2026, 8, 19, 9)),
            MergedPR(title: "c", url: URL(string: "https://e/3")!, repo: "o/a", mergedAt: date(2026, 8, 17, 12)),
            MergedPR(title: "old", url: URL(string: "https://e/4")!, repo: "o/a", mergedAt: date(2026, 8, 10, 12))
        ]
        let days = WeekMath.days(prs: prs, now: today, calendar: calendar)
        XCTAssertEqual(days.count, 7)
        XCTAssertEqual(days.first?.start, calendar.startOfDay(for: date(2026, 8, 13)))
        XCTAssertTrue(days.last?.isToday == true)
        XCTAssertEqual(days.last?.count, 2)
        XCTAssertEqual(days[4].count, 1) // Aug 17
        XCTAssertEqual(days.map(\.count).reduce(0, +), 3)
    }

    func testLastSevenDaysWindow() {
        let window = DayWindow.lastSevenDays(now: date(2026, 8, 19, 12), calendar: utc)
        XCTAssertEqual(utc.startOfDay(for: window.start), utc.startOfDay(for: date(2026, 8, 13)))
        XCTAssertTrue(window.contains(date(2026, 8, 13, 0)))
        XCTAssertFalse(window.contains(date(2026, 8, 20, 0)))
    }

    private var utc: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 12) -> Date {
        utc.date(from: DateComponents(year: y, month: m, day: d, hour: h))!
    }
}

final class MoodMathTests: XCTestCase {
    private var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func date(_ h: Int, _ m: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 8, day: 19, hour: h, minute: m))!
    }

    func testMorningGraceIsNotCritical() {
        XCTAssertEqual(MoodMath.pace(count: 0, goal: 50, now: date(8, 30), calendar: calendar), .onTrack)
        XCTAssertEqual(MoodMath.pace(count: 2, goal: 50, now: date(8, 30), calendar: calendar), .ahead)
    }

    func testAfternoonBehindIsDangerOrCritical() {
        // 16:00 is 8h into a 16h window → expected 25/50
        XCTAssertEqual(MoodMath.pace(count: 25, goal: 50, now: date(16), calendar: calendar), .onTrack)
        XCTAssertEqual(MoodMath.pace(count: 30, goal: 50, now: date(16), calendar: calendar), .ahead)
        XCTAssertEqual(MoodMath.pace(count: 14, goal: 50, now: date(16), calendar: calendar), .danger)
        XCTAssertEqual(MoodMath.pace(count: 5, goal: 50, now: date(16), calendar: calendar), .critical)
    }

    func testGoalHitIsDone() {
        XCTAssertEqual(MoodMath.pace(count: 50, goal: 50, now: date(10), calendar: calendar), .done)
        XCTAssertEqual(MoodMath.pace(count: 80, goal: 50, now: date(10), calendar: calendar), .done)
    }

    func testRace() {
        XCTAssertEqual(MoodMath.race(you: 3, them: 1, hasRival: true), .winning)
        XCTAssertEqual(MoodMath.race(you: 1, them: 4, hasRival: true), .losing)
        XCTAssertEqual(MoodMath.race(you: 2, them: 2, hasRival: true), .tied)
        XCTAssertEqual(MoodMath.race(you: 0, them: 9, hasRival: false), .none)
    }
}

final class NotchLayoutTests: XCTestCase {
    func testCentersOnTopOfScreen() {
        let screen = CGRect(x: 2560, y: 0, width: 1512, height: 982)
        let size = CGSize(width: 380, height: 46)
        let origin = NotchLayout.origin(screenFrame: screen, size: size)
        XCTAssertEqual(origin.x, 2560 + (1512 - 380) / 2)
        XCTAssertEqual(origin.y, 982 - 46)
    }
}

final class RivalMathTests: XCTestCase {
    func testCleansAtAndSpaces() {
        XCTAssertEqual(RivalMath.cleaned("  @IonPop  "), "IonPop")
        XCTAssertEqual(RivalMath.cleaned("bad name!"), "badname")
    }

    func testHeadlineStates() {
        XCTAssertEqual(RivalMath.headline(you: 4, them: 2, rival: "ion"), "You’re up 2 on @ion")
        XCTAssertEqual(RivalMath.headline(you: 1, them: 5, rival: "ion"), "@ion is up 4. Hunt.")
        XCTAssertEqual(RivalMath.headline(you: 3, them: 3, rival: "ion"), "Dead heat with @ion")
        XCTAssertEqual(RivalMath.headline(you: 0, them: 0, rival: ""), "Add a rival to race today")
    }
}

final class TodayFilterTests: XCTestCase {
    func testOnlyTodayMergesSurvive() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let window = DayWindow.local(now: date(2026, 8, 19, 15, 0, calendar: calendar), calendar: calendar)
        let keep = MergedPR(
            title: "keep",
            url: URL(string: "https://example.com/1")!,
            repo: "org/a",
            mergedAt: date(2026, 8, 19, 8, 0, calendar: calendar)
        )
        let drop = MergedPR(
            title: "drop",
            url: URL(string: "https://example.com/2")!,
            repo: "org/b",
            mergedAt: date(2026, 8, 18, 23, 0, calendar: calendar)
        )
        let filtered = [keep, drop].filter { window.contains($0.mergedAt) }
        XCTAssertEqual(filtered.map(\.title), ["keep"])
    }

    private func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int, calendar: Calendar) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }
}
