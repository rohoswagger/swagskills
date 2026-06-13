---
name: connect-chrome
description: Connect to the user's real, running Chrome browser — with all their logged-in sessions — over CDP, instead of launching a fresh unauthenticated browser. Use whenever the user says "use my browser" / "debug in my Chrome", mentions not wanting to log in again, needs to debug or test anything behind auth (SaaS dashboards, SSO-gated local apps, staging sites), or whenever you are about to launch Playwright or any new browser instance for a site that requires login.
---

# connect-chrome — drive the user's real browser

The user tests in their everyday Chrome. It holds their cookies, SSO sessions,
extensions, and exact reproduction state. A freshly launched browser has none of
that, and asking the user to re-authenticate on every service defeats the point
of agent-driven debugging. So the rule is: **never launch a new browser for a
site that needs auth — attach to the one already running.**

## How attachment works (the one fact that matters)

Chrome 136+ ignores `--remote-debugging-port` on the real profile (anti-cookie-theft
hardening). The sanctioned way to expose the *real* browser is a one-time toggle:

> `chrome://inspect/#remote-debugging` → check **"Allow remote debugging for this
> browser instance"**

That opens a CDP WebSocket server on port 9222 for the running browser. It does
**not** serve the HTTP discovery endpoints (`/json/version` 404s) — that's expected,
not broken. The first client connection pops an approval dialog inside Chrome that
the user must accept.

Never "work around" a missing endpoint by relaunching Chrome with `--user-data-dir`:
that creates a blank profile with no logins, which is precisely the failure mode
this skill exists to prevent. If the toggle isn't enabled, ask the user to enable
it — see `references/setup.md` for the exact one-time steps.

## Step 1 — probe

```bash
bash <this-skill's-directory>/scripts/cdp-status.sh    # defaults to port 9222
```

It prints one of three states and the matching connection info:

- `STATUS=full` — CDP with HTTP discovery is up (legacy flag launch, or Chrome for
  Testing). Anything can connect via `http://127.0.0.1:9222`.
- `STATUS=ws_only` — checkbox mode. Connect over WebSocket:
  `ws://127.0.0.1:9222/devtools/browser`. Expect the in-browser approval prompt
  on first connect; tell the user to click Allow.
- `STATUS=off` — not enabled. Relay the one-time setup instructions the script
  prints, wait for the user, re-probe. Do not improvise an alternative launch.

## Step 2 — pick a client

In order of preference:

1. **`mcp__chrome-devtools__*` tools available?** Use them. The server was started
   with `--autoConnect` and is already attached to the user's browser. It covers
   the whole debugging loop: console messages, network requests, screenshots,
   click/fill/navigate, performance traces. (Not registered yet? One-time install
   is in `references/setup.md` — works in both Claude Code and Codex.)
2. **`mcp__claude-in-chrome__*` tools available?** Also already the user's real
   browser (extension-based). Fine for interactive debugging; lacks a scriptable
   layer.
3. **Need a *repeatable, scripted* reproduction** (a flow you'll run many times,
   or want to leave behind as a test)? Use Playwright `connectOverCDP` — most web
   projects already have Playwright installed:

   ```js
   const { chromium } = require('playwright');
   // ws_only mode — pass the ws endpoint; full mode — pass http://127.0.0.1:9222
   const browser = await chromium.connectOverCDP('ws://127.0.0.1:9222/devtools/browser');
   const context = browser.contexts()[0];          // the user's real context — do not create a new one
   const page = await context.newPage();           // always a new tab, never grab theirs
   // ... debug ...
   await browser.close();                          // detaches only; does NOT close the user's Chrome
   ```

   `browser.contexts()[0]` is the logged-in profile; `browser.newContext()` would
   be a blank unauthenticated context — the very thing we're avoiding.
4. **`agent-browser` (Vercel) as CLI fallback**: `agent-browser connect 9222`, then
   `agent-browser snapshot`, etc. Its attach path has known macOS rough edges
   (hangs against externally launched Chrome); if a command stalls >15s, kill it
   and use a client above instead of retrying.

## Rules of engagement — this is the user's real browser

Everything you do happens in their actual logged-in sessions, so treat it like
production access:

- **New tab for everything.** Never navigate, reload, or close a tab you didn't
  open — the user's open tabs are their working state.
- **Read freely, mutate carefully.** Inspecting console/network/DOM/screenshots is
  always fine. Anything that *acts as the user* — submitting forms, sending
  messages, purchases, deletes, changing account settings — needs their explicit
  go-ahead for that specific action.
- **Close what you opened** when done: your tabs, your pages. With `connectOverCDP`,
  `browser.close()` only detaches from the user's Chrome (it never kills it), so
  calling it is safe and correct.
- **Sessions in output:** anything you read may contain auth tokens or personal
  data. Don't paste cookies, `Authorization` headers, or token query params into
  logs, commits, or PRs.

## Debugging recipes

- **Console errors:** chrome-devtools-mcp `list_console_messages`, or in Playwright
  subscribe `page.on('console')` *before* navigating.
- **Failing requests:** chrome-devtools-mcp network tools, or `page.on('response')`
  filtered to `status >= 400`; capture body + request headers (redact tokens).
- **"Works for me, fails for the agent"** is the signature of session-dependent
  behavior — confirm you're in `contexts()[0]` and not a fresh context.
