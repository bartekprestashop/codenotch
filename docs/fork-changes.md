# Codenotch 1.22 fork changes

This branch starts from [Vinz's Codenotch 1.22](https://github.com/vinzdg/codenotch)
at `bcb2889`. The original [MIT license](../LICENSE) and Vinz's copyright
notice are unchanged. This is an independent modification, not an official
Codenotch release. The README's download links lead to upstream builds, which
do not include the features below.

## Agent requests

- Agents can create a short request with a stable ID, project, task, message,
  and Codex chat UUID through `codenotch-request`. The app shows the number of
  open requests on a large orange badge.
- The badge opens a dark, accessible request panel with the full question,
  an **Open Codex chat** link, and a way to clear an orphaned request. The
  usage tooltip stays hidden while the panel is open.
- The request file is owner-only JSON protected by a lock and atomic rename.
  Reopening the same ID is idempotent, and open requests expire after seven
  days. A generation key prevents an old panel action from resolving a newly
  reused ID.
- One configurable reminder can be sent through Telegram after a request
  remains open for the delay, which defaults to 15 minutes. The bot token and
  chat ID are read from macOS Keychain. A claim before network delivery
  prevents duplicate reminders across processes and restarts. A failed
  network attempt is not retried after the claim.
- A new request after app startup plays the selected sound, initially
  **Glass**, unless disabled in Settings. Existing requests on launch,
  duplicate writes, resolution, restart, and opening the panel are silent.
  The sound uses Codenotch's existing macOS sound player.

See [Agent requests](action-requests.md) for setup and the CLI.

## Position and QA

Codenotch 1.22 already supports Option-drag along an edge, remembers a
separate position for each edge, and has **Recentre**. This fork uses those
native controls instead of the old fixed position presets.

The `CodenotchQA` target has a distinct bundle ID and request directory. It
uses sample provider readings and cannot read the normal app's Telegram
credentials, send Telegram reminders, poll live providers, or check for
updates. It can run beside the normal app on a different edge.

## Updates and verification

The fork build omits the upstream Sparkle feed and signing key and disables
both automatic and manual update checks. This prevents an upstream release
from replacing local changes through the app. Future fork builds require
separate review and installation until a fork-owned update channel exists.

The port and updater guard passed 2,138 tests with 9 skipped and no failures.
Independent QA checked the request CLI, file permissions, focused reminder
and position tests, and the isolated UI flow. On the installed build,
Option-drag worked and saved a right-edge offset. Real Telegram delivery,
audible notification from a new request, and the exact private chat destination
remain separate acceptance checks.

For local ad-hoc signing, `make install` disables hardened runtime. A Release
app with both ad-hoc signing and hardened runtime cannot load its embedded
Sparkle framework on macOS. A future Developer ID-signed release retains the
project's hardened-runtime default.
