# Codenotch — fork `bartekprestashop/codenotch`

This is an independent macOS fork of [Codenotch by Vinz](https://github.com/vinzdg/codenotch),
based on upstream 1.22. It keeps the original [MIT license](LICENSE) and
Vinz's attribution. The fork's current source version is **1.22.1** (build 25),
marked by [`fork-v1.22.1`](https://github.com/bartekprestashop/codenotch/tree/fork-v1.22.1).

**This fork is published as source code only.** There is no fork DMG, installer,
binary GitHub Release, or update feed. The upstream app's downloads do not
contain the features listed below. The additions in this fork target **macOS**;
the inherited `windows/` project does not contain them.

## What this fork adds

- **Requests from agents.** `codenotch-request` opens a request with a stable ID,
  project, task, question, and Codex chat UUID. The notch shows an orange count
  of open requests; a dark panel shows the question and opens the related Codex
  chat. Agents resolve requests through the CLI; the panel can clear orphaned
  requests.
- **Attention when a request needs you.** A new request can play a configurable
  sound. If it remains open, the running app can send one Telegram reminder
  after 15 minutes by default. The bot token and chat ID come from macOS
  Keychain. The reminder delay and sound can be configured in Settings.
- **Codex weekly workday plan.** The Codex Usage tooltip marks the planned
  consumption on the existing weekly limit bar. The plan distributes the
  seven-day allowance across local Monday–Friday time, including partial days,
  and pauses through weekends. The tooltip shows the plan, the difference in
  percentage points, and whether usage is ahead of plan or there is room. It
  works when Codex reports the weekly window as `primary` or `secondary` and
  does not change the 5-hour limit or collapsed notch.
- **Safe local verification.** `CodenotchQA` has a separate bundle ID and sample
  readings; it does not use normal account credentials or send Telegram
  reminders. Fork builds also disable upstream automatic updates, so an
  upstream release cannot silently replace these additions.

The original app's usage rings, provider adapters, session states, reset
times, placement controls, and other features remain available. See the
[fork changelog](CHANGELOG.md) for this version and the focused documentation
for [agent requests](docs/action-requests.md), [Codex workday pace](docs/codex-workday-pace.md),
and [all fork changes](docs/fork-changes.md).

## Build and run on macOS

You need Xcode and macOS 15 or later. Clone **this fork**, then build it:

```sh
git clone https://github.com/bartekprestashop/codenotch.git
cd codenotch
brew install xcodegen
make test
make run
```

`make run` builds and opens a local Debug app, stopping an already running
Codenotch instance first. A local ad-hoc build may ask again for Keychain
access after rebuilding. To build the request CLI separately, run
`make request-cli`; setup and examples are in [Agent requests](docs/action-requests.md).
No signing identity is required for `make test` or a basic local run. This
repository does not provide a signed or notarized fork installer.

## Original project

- [Vinz's Codenotch repository](https://github.com/vinzdg/codenotch)
- [Original upstream 1.22 README](https://github.com/vinzdg/codenotch/blob/bcb28894d1514fef5a810595d64b44a3817c2076/README.md) — full provider catalog, upstream downloads, Windows, phone app, and original build documentation

Those links describe the **original project**. Its binaries and update channel
do not include this fork's additions. The upstream authorship and license are
preserved in [LICENSE](LICENSE).
