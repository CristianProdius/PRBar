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
