# Task board (fork 1.22.3)

The board is a compact overview of ongoing Codex work. It uses
`~/Library/Application Support/Codenotch/ActionRequests/task-board.json`, next
to but independent of `requests.json`. Task signals never create action
requests or Telegram reminders. The app reads the board about every two
seconds; agents update it through `codenotch-task`, rather than editing JSON.

Build the CLI with `make task-cli`. Install or invoke `build/codenotch-task`.
`CODEX_THREAD_ID` supplies `--thread` for `upsert` when available;
`CODEX_HOST_ID` supplies its optional `--host`.

```sh
codenotch-task upsert --id catalog-migration --title "Catalog migration" \
  --thread 11111111-1111-4111-8111-111111111111 --total 7
codenotch-task progress --id catalog-migration --completed 3
codenotch-task substatus --id catalog-migration --value coding
codenotch-task add-thread --id catalog-migration \
  --thread 33333333-3333-4333-8333-333333333333
codenotch-task signal --id catalog-migration --value needs_user \
  --thread 22222222-2222-4222-8222-222222222222
codenotch-task signal --id catalog-migration --value none
codenotch-task complete --id catalog-migration
codenotch-task list --all
codenotch-task resume --id catalog-migration
```

`upsert` creates a task with total 5 and completed 0 unless specified. For an
existing task, omitted progress values are preserved. Its `--thread` is the
coordinator conversation. `add-thread` records another conversation without
changing the coordinator or status. A signal can specify a source `--thread`,
which is added to the task's conversations. A row opens that source while its signal is
active, otherwise the coordinator. `--host` can accompany either thread.
Accepted signals: `none`, `problem` (yellow), `blocked` (red), `needs_user`
(orange), and `paused` (gray). The signal is separate from progress and from
the lifecycle. `complete` retains the record but hides it from the active
board; `resume` makes it visible again. `list` shows active tasks; `list --all`
includes completed ones. No command automatically deletes old tasks.

The four tabs filter one collection of active tasks. `Wszystkie` is the
default and shows every active task. `Przygotowanie`, `Kodowanie` and `QA`
show tasks with the corresponding `substatus`. Agents change that field with
`codenotch-task substatus --id ID --value preparation|coding|qa`; the panel
does not edit task data. Substatus is independent of progress and signal.
Older records without the field decode as `preparation` and remain visible in
Wszystkie and Przygotowanie. Completed tasks are absent from all four counts.

The file is a JSON object with `schemaVersion: 1` and a `tasks` array. Each
record has stable `id`, `title`, `completed`, `total`, `lifecycle`, `signal`,
`substatus`, `conversations` (`threadID`, optional `hostID`), `coordinatorThreadID`, optional
`signalThreadID`, immutable `createdAt`, and `updatedAt`. Dates are encoded by
Swift's `JSONEncoder` as seconds since **2001-01-01 00:00:00 UTC**, not Unix
timestamps. The [complete fictional task-board example](examples/task-board.json)
shows the document shape. `coordinatorThreadID` identifies the ordinary row
link; optional `signalThreadID` can route an active signal to another recorded
conversation. The example's UUID and dates are invented. The displayed
date is `updatedAt`, and identical retries do not change it. The store checks
`0 <= completed <= total`, valid thread UUIDs, and schema version before
writing; a lock and atomic file replacement protect concurrent agents.

For isolated CLI testing, set `CODENOTCH_TASK_DIRECTORY` to a scratch folder.
The separate CodenotchQA app reads its own QA Application Support folder.

## Verification for 1.22.3

The full Xcode suite passed with **2,162 tests, nine skipped and zero
failures**. The Release build and strict code-signature verification passed.
Independent QA passed nine focused model tests, legacy and invalid-data CLI
checks, permissions and request-store isolation. With 15 tasks in the QA app,
the filters counted 15 / 12 / 2 / 1 and showed the expected rows. A CLI
substatus change updated an open panel; completion updated counts and the
empty view. QA found a reopen-height bug; after the fix, closing a one-row QA
view and reopening Wszystkie displayed the full list, including the last row
after scrolling.

The local 1.22.3 app displayed all four filters. Three clearly labeled demo
records were assigned to different substatus filters without changing their
progress or signals. The app read account usage normally. The user manually
confirmed that clicking a task opened the correct Codex chat. Other monitor
layouts remain unverified. The previous app, CLI and board JSON were backed
up before installation.

## Verification for the 1.22.2 local candidate

`make task-cli` compiled and an isolated CLI smoke test covered create,
progress, signals, complete and resume. The full Xcode suite passed with
2,159 tests run, nine skipped and zero failures. The added geometry test
covered one, two and three providers on all four notch edges. Independent QA
tested malformed documents, file permissions, idempotent retries and 64
concurrent writes; its verdict was **PASS WITH RISKS**. In the isolated QA app,
the icon was visible below the reading with one and three providers, a 15-row
board scrolled, all four signals rendered, and a progress update reached the
open panel without closing it. The local 1.22.2 installation showed the task
button with three active sample tasks and rendered their titles, progress and
signals in the panel. The three records use verified Codex conversation IDs.
The operating system blocked accessibility inspection of the Codex window
after a row click, so the destination chat could not be confirmed visually in
this run. Real deep links and other display configurations remain for user
acceptance testing.
