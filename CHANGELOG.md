# Fork changelog

This is an independent fork of [Vinz's Codenotch](https://github.com/vinzdg/codenotch).
It keeps the original [MIT license](LICENSE) and attribution. Version numbers
refer to this fork's source; download links in the README lead to upstream
binary releases unless stated otherwise.

## fork-v1.22.1 — 2026-10-09

- Added a marker to the Codex weekly usage bar showing where even use across
  local Monday–Friday time would be now. The tooltip gives the planned percent,
  difference in percentage points, and a short ahead/on/behind status. Weekends
  do not advance the plan; partial workdays and daylight saving time are counted.
- Handles both Codex account layouts: a seven-day allowance in `secondary`, or
  a sole seven-day `primary` window. The 5-hour limit, Spark and code-review
  windows, other providers, and the collapsed notch keep their prior behavior.
- Includes Polish text for the new status, an isolated QA fixture, calculation
  and render tests, and [technical notes](docs/codex-workday-pace.md).

Verification: 2,152 tests ran with nine skipped and no failures. Independent QA
passed 56 focused tests. The preceding local feature build was signed,
installed and checked with a primary-only weekly layout; this 1.22.1 source
version has not been installed.
Automated UI control could not hold hover long enough to confirm the live
tooltip on screen. The new phrases fall back to English outside Polish.

This source tag has no fork binary release or update feed.

## 1.22.0 fork base

Ported the agent request panel, request CLI, sound, delayed Telegram reminder,
and isolated QA target to upstream Codenotch 1.22. See [fork changes](docs/fork-changes.md)
for details. Automatic upstream updates are disabled in the fork so they cannot
replace its additions.
