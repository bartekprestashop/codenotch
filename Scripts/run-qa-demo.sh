#!/bin/sh
set -eu

# The bundle itself enforces isolation via CodenotchQAMode in Info.plist.
# The QA bundle has a distinct bundle ID and data directory. It can run
# alongside the normal app when placed on a different edge.
qa_app="${1:-$HOME/Library/Application Support/Codenotch QA/CodenotchQA.app}"

if [ ! -d "$qa_app" ]; then
    echo "Codenotch QA app not found: $qa_app" >&2
    exit 1
fi
if pgrep -x CodenotchQA >/dev/null; then
    echo "Codenotch QA is already running." >&2
    exit 1
fi

exec /usr/bin/open -n "$qa_app"
