# One-time setup

Two pieces: expose the running browser (user does once), and register a CDP
client in each agent harness (done once per machine).

## 1. Expose the real browser (Chrome 144+)

In the user's normal Chrome:

1. Open `chrome://inspect/#remote-debugging`
2. Check **"Allow remote debugging for this browser instance"**
3. Restart Chrome if prompted

This starts a CDP WebSocket server on port 9222 bound to localhost, serving the
*real* profile. The HTTP discovery endpoints (`/json/version`, `/json/list`) are
intentionally absent in this mode. Each new client connection triggers an
approval dialog inside Chrome.

Background: Chrome 136+ ignores `--remote-debugging-port` unless paired with a
non-default `--user-data-dir` (anti-cookie-theft hardening, see
https://developer.chrome.com/blog/remote-debugging-port). The checkbox is the
supported path for debugging the logged-in profile.

## 2. Register chrome-devtools-mcp (preferred client)

Google's official DevTools MCP server. `--autoConnect` makes it attach to the
checkbox-enabled running browser automatically.

**Claude Code** (user scope, available in every project):

```bash
claude mcp add chrome-devtools --scope user -- npx -y chrome-devtools-mcp@latest --autoConnect
```

**Codex** — add to `~/.codex/config.toml`:

```toml
[mcp_servers.chrome-devtools]
command = "npx"
args = ["-y", "chrome-devtools-mcp@latest", "--autoConnect"]
startup_timeout_ms = 20000
```

Verify from a fresh agent session: ask it to "take a screenshot of my current
browser tab" — the approval dialog appears in Chrome on first attach.

## Fallback: persistent debug profile

If the user cannot or will not enable the checkbox, the only honest alternative
is a *persistent* secondary profile they log into once and reuse:

```bash
open -na "Google Chrome" --args \
  --remote-debugging-port=9222 \
  --user-data-dir="$HOME/.chrome-agent-profile"
```

Logins stick across runs because the data dir persists, but this is a second
browser with its own sessions — offer it only if the checkbox route is refused,
and say so plainly rather than presenting it as equivalent.
