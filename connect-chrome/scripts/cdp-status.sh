#!/usr/bin/env bash
# Probe the user's running Chrome for a CDP endpoint and report how to connect.
# Usage: cdp-status.sh [port]   (default 9222)
set -u

PORT="${1:-9222}"
BODY="$(mktemp)"
trap 'rm -f "$BODY"' EXIT

CODE=$(curl -sS -o "$BODY" -w '%{http_code}' -m 2 "http://127.0.0.1:${PORT}/json/version" 2>/dev/null) || CODE=000

case "$CODE" in
  200)
    echo "STATUS=full"
    echo "CDP with HTTP discovery is up on port ${PORT}."
    echo "HTTP_ENDPOINT=http://127.0.0.1:${PORT}"
    WS=$(python3 -c "import json,sys; print(json.load(open(sys.argv[1]))['webSocketDebuggerUrl'])" "$BODY" 2>/dev/null || true)
    [ -n "${WS:-}" ] && echo "WS_ENDPOINT=${WS}"
    ;;
  404|403)
    echo "STATUS=ws_only"
    echo "CDP is listening on port ${PORT} but HTTP discovery is disabled."
    echo "This is Chrome's checkbox mode (chrome://inspect/#remote-debugging) - expected, not broken."
    echo "WS_ENDPOINT=ws://127.0.0.1:${PORT}/devtools/browser"
    echo "NOTE: the first connection pops an approval dialog inside Chrome; the user must click Allow."
    ;;
  *)
    echo "STATUS=off"
    echo "Nothing is answering on port ${PORT}."
    echo "Relay this one-time setup to the user (do it in their normal running Chrome):"
    echo "  1. Open chrome://inspect/#remote-debugging"
    echo "  2. Check 'Allow remote debugging for this browser instance'"
    echo "  3. Restart Chrome if prompted, then re-run this script."
    echo "Do NOT relaunch Chrome with --user-data-dir to work around this - that is a"
    echo "fresh profile with no logins, which defeats the purpose of attaching."
    ;;
esac
