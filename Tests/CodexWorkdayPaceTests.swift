import XCTest
@testable import Codenotch

final class CodexWorkdayPaceTests: XCTestCase {
    private var warsaw: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Warsaw")!
        return calendar
    }

    private func date(_ day: Int, _ hour: Int = 9,
                      month: Int = 10, year: Int = 2026) -> Date {
        warsaw.date(from: DateComponents(year: year, month: month, day: day,
                                         hour: hour))!
    }

    private func weekly(reset: Date, used: Double? = 0.5,
                        duration: TimeInterval? = 7 * 86400) -> LimitWindow {
        LimitWindow(id: "secondary", label: "Weekly limit", usedFraction: used,
                    resetsAt: reset, duration: duration)
    }

    func testTwoOfFiveWorkdaysMeansFortyPercentPlan() throws {
        let pace = try XCTUnwrap(CodexWorkdayPace.calculate(
            window: weekly(reset: date(14)), now: date(9), calendar: warsaw))
        XCTAssertEqual(pace.plannedFraction, 0.4, accuracy: 0.000001)
        XCTAssertEqual(pace.differencePoints, 10, accuracy: 0.000001)
    }

    func testWeekendInMiddleDoesNotAdvancePlan() throws {
        let window = weekly(reset: date(14))
        let saturday = try XCTUnwrap(CodexWorkdayPace.calculate(
            window: window, now: date(10, 12), calendar: warsaw))
        let sunday = try XCTUnwrap(CodexWorkdayPace.calculate(
            window: window, now: date(11, 12), calendar: warsaw))
        XCTAssertEqual(saturday.plannedFraction, sunday.plannedFraction,
                       accuracy: 0.000001)
        XCTAssertEqual(saturday.plannedFraction, 0.525, accuracy: 0.000001)
    }

    func testWeekendResetAndPartialWorkday() throws {
        let pace = try XCTUnwrap(CodexWorkdayPace.calculate(
            window: weekly(reset: date(11)), now: date(7, 12), calendar: warsaw))
        XCTAssertEqual(pace.plannedFraction, 0.5, accuracy: 0.000001)
        XCTAssertEqual(pace.differencePoints, 0, accuracy: 0.000001)
    }

    func testBeginningAndEndOfCycle() throws {
        let reset = date(14)
        let window = weekly(reset: reset)
        let start = reset.addingTimeInterval(-7 * 86400)
        XCTAssertEqual(try XCTUnwrap(CodexWorkdayPace.calculate(
            window: window, now: start, calendar: warsaw)).plannedFraction, 0)
        XCTAssertEqual(try XCTUnwrap(CodexWorkdayPace.calculate(
            window: window, now: reset.addingTimeInterval(-1),
            calendar: warsaw)).plannedFraction, 1, accuracy: 0.00001)
        XCTAssertNil(CodexWorkdayPace.calculate(window: window, now: reset,
                                                calendar: warsaw))
        XCTAssertNil(CodexWorkdayPace.calculate(window: window,
            now: start.addingTimeInterval(-1), calendar: warsaw))
    }

    func testMissingAndNonweeklyDataDoNotShowPlan() {
        let reset = date(14)
        let now = date(9)
        for window in [
            weekly(reset: reset, used: nil),
            weekly(reset: reset, used: .infinity),
            weekly(reset: reset, used: -0.1),
            weekly(reset: reset, duration: nil),
            weekly(reset: reset, duration: 5 * 3600),
            weekly(reset: reset, duration: 30 * 86400),
            LimitWindow(id: "secondary", label: "Weekly limit", usedFraction: 0.5,
                        duration: 7 * 86400)
        ] {
            XCTAssertNil(CodexWorkdayPace.calculate(window: window, now: now,
                                                     calendar: warsaw))
        }
    }

    func testOnlyCodexAccountWeeklyWindowIsEligible() {
        let now = date(9)
        let window = weekly(reset: date(14))
        var snapshot = ProviderSnapshot(id: "claude", displayName: "Claude",
            glyph: .claude, fidelity: .official, status: .ok, windows: [window],
            weeklyID: "secondary")
        XCTAssertNil(snapshot.codexWorkdayPace(now: now, calendar: warsaw))
        snapshot = ProviderSnapshot(id: "codex", displayName: "Codex",
            glyph: .openai, fidelity: .official, status: .ok, windows: [window],
            weeklyID: "secondary")
        XCTAssertNotNil(snapshot.codexWorkdayPace(now: now, calendar: warsaw))
        XCTAssertNil(snapshot.codexWorkdayPace(for: LimitWindow(id: "primary",
            label: "5h", usedFraction: 0.5, resetsAt: now.addingTimeInterval(3600),
            duration: 5 * 3600), now: now, calendar: warsaw))
        XCTAssertNil(snapshot.codexWorkdayPace(for: LimitWindow(id: "spark",
            label: "Spark weekly", usedFraction: 0.5, resetsAt: date(14),
            duration: 7 * 86400), now: now, calendar: warsaw))
    }

    func testCodexPrimaryCanBeTheOnlyWeeklyWindow() throws {
        let now = date(9)
        let primary = LimitWindow(id: "primary", label: "Weekly limit",
            usedFraction: 0.61, resetsAt: date(14), duration: 7 * 86400)
        let snapshot = ProviderSnapshot(id: "codex", displayName: "Codex",
            glyph: .openai, fidelity: .official, status: .ok,
            windows: [primary], headlineID: "primary", weeklyID: "secondary")
        let pace = try XCTUnwrap(snapshot.codexWorkdayPace(now: now, calendar: warsaw))
        XCTAssertEqual(pace.displayedDifferencePoints, 21)
        XCTAssertEqual(snapshot.codexWorkdayPace(for: primary, now: now,
            calendar: warsaw), pace)
    }

    func testOnlyOneAccountWindowGetsPaceWhenBothLastSevenDays() throws {
        let now = date(9)
        let primary = weekly(reset: date(14), used: 0.61)
        let first = LimitWindow(id: "primary", label: "Weekly limit",
            usedFraction: primary.usedFraction, resetsAt: primary.resetsAt,
            duration: primary.duration)
        let snapshot = ProviderSnapshot(id: "codex", displayName: "Codex",
            glyph: .openai, fidelity: .official, status: .ok,
            windows: [first, primary], headlineID: "primary", weeklyID: "secondary")
        XCTAssertNil(snapshot.codexWorkdayPace(for: first, now: now,
            calendar: warsaw))
        XCTAssertNotNil(snapshot.codexWorkdayPace(for: primary, now: now,
            calendar: warsaw))
        XCTAssertNotNil(snapshot.codexWorkdayPace(now: now, calendar: warsaw))
    }

    func testDSTWeekendDoesNotAddPlanTime() throws {
        let reset = date(28)
        let window = weekly(reset: reset)
        let saturday = try XCTUnwrap(CodexWorkdayPace.calculate(
            window: window, now: date(24, 12), calendar: warsaw))
        let sunday = try XCTUnwrap(CodexWorkdayPace.calculate(
            window: window, now: date(25, 12), calendar: warsaw))
        XCTAssertEqual(saturday.plannedFraction, sunday.plannedFraction,
                       accuracy: 0.000001)
    }

    func testDisplayedDifferenceRoundsBeforeStatusSelection() {
        XCTAssertEqual(CodexWorkdayPace(usedFraction: 0.401, plannedFraction: 0.4)
            .displayedDifferencePoints, 0)
        XCTAssertEqual(CodexWorkdayPace(usedFraction: 0.399, plannedFraction: 0.4)
            .displayedDifferencePoints, 0)
        XCTAssertEqual(CodexWorkdayPace(usedFraction: 0.406, plannedFraction: 0.4)
            .displayedDifferencePoints, 1)
        XCTAssertEqual(CodexWorkdayPace(usedFraction: 0.394, plannedFraction: 0.4)
            .displayedDifferencePoints, -1)
        XCTAssertEqual(CodexWorkdayPace(usedFraction: 0.5049, plannedFraction: 0.4951)
            .displayedDifferencePoints, 0)
    }

    func testOverLimitUsageKeepsTheDisplayedDifference() throws {
        let pace = try XCTUnwrap(CodexWorkdayPace.calculate(
            window: weekly(reset: date(14), used: 1.2), now: date(9),
            calendar: warsaw))
        XCTAssertEqual(pace.usedFraction, 1.2)
        XCTAssertEqual(pace.displayedDifferencePoints, 80)
    }
}
