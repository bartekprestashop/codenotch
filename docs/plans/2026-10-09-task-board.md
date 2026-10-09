# Task board for the macOS fork (1.22.2)

## Context and scope

The 1.22.1 fork already has a request store, two-second monitor, and a dark
request panel. The task board is a separate overview of ongoing work. It must
not turn warning signals into requests or Telegram messages. The approved
visual reference is `codenotch-task-board-alerts.png` in the October 7 voice
chat outputs. The current app must keep its existing request data and Keychain
access intact.

## Technical approach

- Store `task-board.json` next to `requests.json` in
  `~/Library/Application Support/Codenotch/ActionRequests`. Give it its own
  lock file; write a complete temporary file with mode 0600 and rename it.
  The JSON document has a `schemaVersion` and an array of tasks.
- Each task has a stable ID, short title, `completed`/`total` (default total
  5), lifecycle `active`/`completed`, independent signal `none`/`problem`/
  `blocked`/`needs_user`/`paused`, `createdAt`, and `updatedAt`. It also records
  multiple Codex conversations, a coordinator thread, and an optional signal
  source. The row opens the signal source when a signal is set, otherwise the
  coordinator. `updatedAt` changes only when stored task content changes.
- Provide a narrow `codenotch-task` CLI for upsert, progress, signal,
  complete, resume, and list. Validate UUIDs, membership of selected threads,
  bounds, IDs and title. An identical command must leave the file and
  `updatedAt` untouched.
- Poll the separate file about every two seconds, publish only active tasks,
  and use a separate dark panel with compact rows, fixed-width progress bars,
  status overlays, ellipsized title, a short local update date, capped height
  and scrolling. QA uses a separate Application Support directory. The
  opener's placement must be approved against the real narrow right-edge notch.
- Bump source version to 1.22.2/build 26. Do not publish this version.

## Risks and verification

- Concurrent CLI writers: lock and atomic replacement, with tests covering
  stale and idempotent updates.
- Panel click routing and 10–15 rows: verify in the app and QA target, including
  scrolling and conversation destination. Seed demo tasks only after the
  user's explicit approval.
- Data isolation: verify existing `requests.json` and Keychain are unchanged;
  task signals must not touch the reminder monitor. After approval and local
  installation, seed exactly three clearly labeled sample tasks linked to
  verified existing Codex chats, as the user requested. Do not seed requests.
- Run model/CLI unit tests and the full Xcode test suite; then independent QA.
  Local installation and account smoke test follow QA. Publishing requires a
  separate user instruction.

## Result on 2026-10-09

Implementation and isolated QA complete. `make test`: 2,159 tests run, nine
skipped, zero failures. Independent QA: PASS WITH RISKS; 64 concurrent CLI
writes preserved every record, malformed JSON was rejected, and the task store
did not modify requests. Visual QA checked one and three providers, 15 rows,
scrolling, all signal colors and live progress update in an open panel.
The local app was installed and displayed the approved three labeled examples.
In the later 1.22.3 update, the user manually confirmed that a row opens the
correct Codex chat. The final task-board verification is in
[`docs/task-board.md`](../task-board.md).
