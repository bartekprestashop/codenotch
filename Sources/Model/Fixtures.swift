import Foundation

/// The three providers from the design frame, at the levels it shows.
/// These stand in until the adapters in M4 land.
enum Fixtures {
    /// Synthetic account weekly reading for the isolated QA app. No provider
    /// session, Keychain item, or network request is involved.
    static func codexWorkdayPace(now: Date = Date(), calendar: Calendar = .current)
    -> ProviderSnapshot {
        var resetTime = DateComponents()
        resetTime.weekday = 4
        resetTime.hour = 9
        resetTime.minute = 0
        resetTime.second = 0
        let reset = calendar.nextDate(
            after: now,
            matching: resetTime,
            matchingPolicy: .nextTime
        ) ?? now.addingTimeInterval(7 * 86400)
        return ProviderSnapshot(
            id: "codex", displayName: "Codex", glyph: .openai,
            fidelity: .official, status: .ok,
            windows: [
                LimitWindow(id: "primary", label: L10n.t("5h limit"),
                            usedFraction: 0.32,
                            resetsAt: now.addingTimeInterval(2 * 3600), duration: 5 * 3600),
                LimitWindow(id: "secondary", label: L10n.t("Weekly limit"),
                            usedFraction: 0.51, resetsAt: reset, duration: 7 * 86400)
            ], headlineID: "primary", weeklyID: "secondary"
        )
    }

    static func snapshots(now: Date = Date(), calendar: Calendar = .current) -> [ProviderSnapshot] {
        let sessionReset = now.addingTimeInterval(51 * 60)
        let midnight = calendar.startOfDay(for: now.addingTimeInterval(24 * 60 * 60))

        return [
            ProviderSnapshot(
                id: "claude",
                displayName: "Claude",
                glyph: .claude,
                fidelity: .derived,
                status: .ok,
                windows: [
                    LimitWindow(id: "claude.session", label: L10n.t("Current session"),
                                usedFraction: 0.73, resetsAt: sessionReset),
                    LimitWindow(id: "claude.all", label: L10n.t("All models"),
                                usedFraction: 0.07, resetsAt: midnight)
                ]
            ),
            ProviderSnapshot(
                id: "openai",
                displayName: "OpenAI",
                glyph: .openai,
                fidelity: .manual,
                status: .ok,
                windows: [
                    LimitWindow(id: "openai.session", label: L10n.t("Current session"),
                                usedFraction: 0.21, resetsAt: now.addingTimeInterval(3 * 60 * 60))
                ]
            ),
            ProviderSnapshot(
                id: "third",
                displayName: "Perplexity",
                glyph: .third,
                fidelity: .manual,
                status: .ok,
                windows: [
                    LimitWindow(id: "third.daily", label: L10n.t("Daily quota"),
                                usedFraction: 0.52, resetsAt: midnight)
                ]
            )
        ]
    }
}
