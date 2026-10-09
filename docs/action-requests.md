# Agent requests

Agents can open a short request in the notch when they need a response. The
request list links to the source Codex chat. The agent resolves the request
after handling the answer. Open requests expire after seven days.

## Build the command

```sh
make request-cli
```

The command is `build/codenotch-request`. It writes to
`~/Library/Application Support/Codenotch/ActionRequests/requests.json`, shared
with the app. A separate directory can be selected for tests with
`CODENOTCH_REQUEST_DIRECTORY`.

## Open and resolve a request

Use a stable ID for one question. Provide the Codex thread UUID explicitly or
set `CODEX_THREAD_ID` in the agent environment. `CODEX_HOST_ID` is optional.

```sh
build/codenotch-request open \
  --id project:deployment-approval \
  --project Example \
  --task 'Approve deployment' \
  --message 'Review the prepared release and approve deployment.' \
  --thread "$CODEX_THREAD_ID"

build/codenotch-request list
build/codenotch-request resolve --id project:deployment-approval
```

Opening the same ID twice is idempotent: it does not restart the timer or
create a second reminder. Resolve the ID before opening a new question with
that ID. The command rejects invalid thread UUIDs, overlong fields, and
missing required fields.

## Local JSON format

The CLI creates the directory and `requests.json` on its first write. It is a
JSON **array** of open requests; an empty array means there are none. See the
[complete fictional example](examples/requests.json). `id` identifies one
question; `project`, `task` and `message` are shown in the notch and can also
appear in the optional Telegram reminder. `threadID` is the Codex chat UUID,
and optional `hostID` selects its host. `createdAt` and `expiresAt` are JSON
numbers in seconds since **2001-01-01 00:00:00 UTC**, Swift's reference date,
not Unix timestamps. The example's future dates and UUIDs are invented.
`generation` distinguishes a reopened ID; older records may omit it.
`reminderClaimedAt` is absent until the app claims a reminder, then uses the
same date format. The CLI manages these fields and writes owner-only files;
use `open` and `resolve` rather than editing JSON. Codenotch displays and
links requests, and may update expiry or reminder state in this file.

Keep the message brief and free of secrets. The request file is stored with
owner-only permissions. The app polls it while running; no message is sent
when the app is closed. The chat link requires Codex to handle the `codex:`
URL scheme on this Mac.

## Telegram reminder

A new request after startup plays the selected request sound by default. Set
**Notifications → Agent requests → Play a sound for new requests** to turn it
off or choose another sound. Existing requests at launch, repeated writes,
resolutions, and opening the panel are silent. Sounds use the normal macOS
audio output and follow its volume settings.

The app sends at most one reminder for each request still open after the
configured delay. The default is 15 minutes; Settings allows 5 to 1440
minutes in 5-minute steps. No credentials means no Telegram message.

Create two **generic password** items in macOS Keychain Access:

| Service | Account | Secret value |
| --- | --- | --- |
| `com.vinz.codenotch.telegram` | `bot-token` | Your Telegram bot token |
| `com.vinz.codenotch.telegram` | `chat-id` | The intended chat ID |

Keychain may ask you to allow this app to access those items. Grant access only
to a build you trust. The reminder text includes the request's project, task,
and message; do not put private data there unless that Telegram chat is an
appropriate destination. If network delivery fails after a reminder is
claimed, it is not retried automatically, to avoid duplicate messages.

## Verify safely

`make test` runs the request store and reminder tests. `CodenotchQA` is a
separate, isolated app target for visual checks. Its `CodenotchQAMode` setting
prevents provider polling, credential reads, updates, and Telegram delivery.
The normal app can stay open if the QA notch is placed on another edge.
`Scripts/run-qa-demo.sh /path/to/CodenotchQA.app` launches a built QA app;
without an argument it looks in `~/Library/Application Support/Codenotch QA/`.
The QA app stores its test requests separately from the normal app.

On macOS, the notch can be moved by holding Option and dragging. Codenotch
1.22 remembers a separate position for each edge; the Appearance pane has a
Recentre button. No additional position selector is needed.
