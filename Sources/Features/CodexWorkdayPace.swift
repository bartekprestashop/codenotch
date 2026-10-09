import Foundation

/// The weekly Codex allowance spread evenly across local Monday–Friday time.
/// This is a comparison at `now`, not a forecast of when quota will run out.
struct CodexWorkdayPace: Equatable {
    let usedFraction: Double
    let plannedFraction: Double

    var differencePoints: Double { (usedFraction - plannedFraction) * 100 }
    /// Match the whole percentages printed beside the bar, so a displayed
    /// 50% used against a displayed 50% plan never claims a +1 pp gap.
    var displayedDifferencePoints: Int {
        Int((usedFraction * 100).rounded()) - Int((plannedFraction * 100).rounded())
    }

    static func calculate(window: LimitWindow, now: Date,
                          calendar: Calendar = .current) -> CodexWorkdayPace? {
        let week: TimeInterval = 7 * 24 * 3600
        guard let duration = window.duration, duration.isFinite,
              abs(duration - week) < 60,
              let reset = window.resetsAt, reset > now,
              let used = window.usedFraction, used.isFinite, used >= 0,
              used < Double(Int.max) / 100 else { return nil }

        let start = reset.addingTimeInterval(-duration)
        guard now >= start else { return nil }
        var local = Calendar(identifier: .gregorian)
        local.timeZone = calendar.timeZone
        let total = workdaySeconds(from: start, to: reset, calendar: local)
        guard total > 0 else { return nil }
        let elapsed = workdaySeconds(from: start, to: now,
                                     calendar: local)
        return CodexWorkdayPace(usedFraction: used,
                               plannedFraction: min(max(elapsed / total, 0), 1))
    }

    private static func workdaySeconds(from start: Date, to end: Date,
                                       calendar: Calendar) -> TimeInterval {
        guard start < end else { return 0 }
        var cursor = start
        var seconds: TimeInterval = 0
        while cursor < end {
            guard let day = calendar.dateInterval(of: .day, for: cursor),
                  day.end > cursor else { break }
            // Gregorian weekday: Sunday = 1, Monday = 2, ..., Saturday = 7.
            if (2...6).contains(calendar.component(.weekday, from: day.start)) {
                seconds += max(0, min(end, day.end).timeIntervalSince(max(start, day.start)))
            }
            cursor = day.end
        }
        return seconds
    }
}

extension ProviderSnapshot {
    func codexWorkdayPace(for window: LimitWindow, now: Date,
                          calendar: Calendar = .current) -> CodexWorkdayPace? {
        guard let selected = selectedCodexWeeklyWindow(now: now, calendar: calendar),
              selected.id == window.id else { return nil }
        return selected.pace
    }

    func codexWorkdayPace(now: Date, calendar: Calendar = .current) -> CodexWorkdayPace? {
        selectedCodexWeeklyWindow(now: now, calendar: calendar)?.pace
    }

    private func selectedCodexWeeklyWindow(now: Date, calendar: Calendar)
    -> (id: String, pace: CodexWorkdayPace)? {
        guard CodexProfile.isCodex(providerID: providerID) else { return nil }
        // Codex can put the seven-day allowance in primary and omit secondary.
        // The window duration, not its display role, determines weekly pace.
        for id in ["secondary", "primary"] {
            if let window = windows.first(where: { $0.id == id }),
               let pace = CodexWorkdayPace.calculate(window: window, now: now,
                                                     calendar: calendar) {
                return (id, pace)
            }
        }
        return nil
    }
}
