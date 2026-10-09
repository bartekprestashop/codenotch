# Task board (fork 1.22.2)

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

The file is a JSON object with `schemaVersion: 1` and a `tasks` array. Each
record has stable `id`, `title`, `completed`, `total`, `lifecycle`, `signal`,
`conversations` (`threadID`, optional `hostID`), `coordinatorThreadID`, optional
`signalThreadID`, immutable `createdAt`, and `updatedAt`. Dates are encoded by
Swift's `JSONEncoder` as seconds from Apple's reference date. The displayed
date is `updatedAt`, and identical retries do not change it. The store checks
`0 <= completed <= total`, valid thread UUIDs, and schema version before
writing; a lock and atomic file replacement protect concurrent agents.

For isolated CLI testing, set `CODENOTCH_TASK_DIRECTORY` to a scratch folder.
The separate CodenotchQA app reads its own QA Application Support folder.

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
