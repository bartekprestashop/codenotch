# Task board filters: technical note

The 1.22.2 board has one collection of tasks in `task-board.json`. Progress,
lifecycle, signal and conversation links are independent. The panel currently
shows every active task in one list, which becomes difficult to scan with
10–15 tasks.

Add an independent `substatus` field with stable CLI values `preparation`,
`coding` and `qa`. The four tabs are filters over the same collection:
Wszystkie (the default), Przygotowanie, Kodowanie and QA. Every active task
appears in Wszystkie and exactly one substatus filter. Counts include only
active tasks. Codenotch only displays and links tasks; agents change
`substatus` through `codenotch-task substatus`, never through the panel.

Existing records without `substatus` decode as `preparation`, including the
three local examples. Keep schema version 1: this is an additive field, and
older decoders ignore it. The first write of a legacy record persists the
default. A substatus change must preserve progress, signal, lifecycle and
conversation links. Completed records stay out of all active filters.

The controller owns the selected filter so polling updates to the SwiftUI
root view do not reset it. The panel resizes within the visible screen and
keeps its compact rows, bars and signals. The approved visual prototype is
`codenotch-task-board-filter-tabs.png` (local design reference).

Verification: decode legacy JSON, update and retry a substatus through the
store and CLI, check invariants and link routing, run the full suite and
Release build, inspect the four filters with 10–15 rows in the isolated QA
app, obtain independent QA, then back up and replace the local app. Do not
publish the fork.
