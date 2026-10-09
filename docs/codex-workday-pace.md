# Codex weekly workday pace

## Context and decision

Codenotch 1.22 already shows each Codex limit's used percentage and reset time in
the hover card. Its optional `UsagePace` compares quota with elapsed wall time for
every timed window. The requested comparison is different: only Codex's account
weekly window, and only Monday–Friday time within that rolling cycle.

Show the comparison in the existing Codex Usage card. Keep its weekly used bar,
percentage, reset copy, and the small notch unchanged. Add one high contrast
vertical plan marker on that bar and two compact text lines for the plan's
current percentage, difference in percentage points, and status. Do not add a new
setting, historical chart, or exhaustion date. Keep the general pace setting for
other windows; avoid duplicate pace text on the Codex weekly row.

## Calculation

The cycle is `[resetsAt - duration, resetsAt)`. Intersect it with each local
Monday–Friday calendar day, accounting for partial first and last days and DST.
The plan is elapsed workday seconds divided by all workday seconds in the cycle.
Only a valid, current seven day Codex account `primary` or `secondary` window
produces a marker. Codex may provide the week as its only `primary` window. A
missing reset, missing duration, nonfinite usage, expired cycle, or a window with
no working time keeps the existing tooltip unchanged. Weekend time holds the
plan steady. The displayed percentage point difference subtracts the two
displayed whole percentages, so its status agrees with the numbers in the
card. Usage above 100% remains above 100% in this comparison, even though the
bar fill ends at the track edge.

## Verification and risks

Test exact plan, ahead/behind, cycle boundaries, weekend reset and middle,
partial days, DST, missing data, and nonweekly Codex windows. Render both one
bar with marker and two bars in the isolated QA context; choose the clearer
variant within the existing card width. Verify the fixed card height, hover
region, and translations. Run project tests and independent QA before a local
install.

The isolated render comparison used the same synthetic 51% weekly reading
and a 24% workday plan for both layouts. Two bars became hairlines at the
existing card scale; the single full bar with a plan marker stayed legible.
The first Polish one-line status truncated, so the final card puts the plan
and percentage-point difference on one line and the status on the next.
Independent QA found and prompted fixes for rounding near zero, rounding when
both percentages display the same integer, and usage above 100%.
The full suite for source version 1.22.1 passed with 2,152 tests run, nine
skipped, and no failures. Independent QA passed 56 focused tests in a
separate DerivedData and rated
the change PASS WITH RISKS. The remaining localization gap is that these five
new strings are translated into Polish, while other non-English locales use
the English source text.

Codex can return a single seven-day `primary` window with no `secondary`
window. The initial implementation hid the plan in that layout. Selection now
uses the duration of account windows and prefers
`secondary` when both qualify, while ignoring Spark and code-review windows.
The separate primary-only regression test and focused render test cover this
shape. A pre-version-bump Release bundle was built and signature-verified. Automated
UI control could not hold a hover long enough to capture the live tooltip, so
the user's visual check remains useful.

For a synthetic live check, launch the `CodenotchQA` build with
`CODENOTCH_QA_CODEX_PACE=1` and hover its Codex ring. This QA target is isolated
from normal provider polling, Keychain credentials, Telegram, and updates.
