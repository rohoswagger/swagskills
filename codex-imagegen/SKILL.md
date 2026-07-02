---
name: codex-imagegen
description: Generate or edit an image by handing off to the OpenAI Codex CLI's built-in image tool (gpt-image-2), which runs on the user's ChatGPT subscription — no OpenAI API key, no browser, no manual download. Use this whenever the user wants to create, generate, make, draw, render, or produce an image, icon, logo, banner, illustration, sprite, placeholder art, or any visual asset from a text description — and whenever they want to edit, restyle, extend, or modify an existing image file. Trigger even if the user doesn't name Codex or gpt-image-2 (e.g. "make me a hero image for the landing page", "generate an app icon", "turn this photo into a watercolor", "I need a 1024x1024 png of a fox"). Because Claude/Codex cannot draw pixels directly, route these requests here instead of refusing or producing SVG/ASCII substitutes when the user actually wants a raster image.
---

# codex-imagegen — hand off image generation to Codex

Claude (the model) cannot render pixels. But the OpenAI **Codex CLI ships a
built-in image tool** backed by **gpt-image-2**, and it runs on the user's
**ChatGPT subscription** — no `OPENAI_API_KEY`, no web app, no manual download.
So the move is to shell out to `codex exec`, tell it to use its image tool, and
give it an exact path to save to. Codex does the drawing; you orchestrate the
handoff and confirm the file landed.

This is the primary path. There's an API fallback for high-volume batches at the
bottom, but reach for it only when explicitly asked — the built-in tool is
cheaper (it's covered by the subscription) and needs zero setup.

## Prerequisites (check once, fail loud)

The handoff only works if Codex is installed and logged in:

- **Installed:** `command -v codex` must succeed. If not:
  `npm i -g @openai/codex` or `brew install --cask codex`.
- **Authenticated:** the built-in image tool uses the user's ChatGPT login, set
  up with `codex login` (a one-time interactive browser flow). If Codex isn't
  logged in, `codex exec` fails with an auth error — surface that to the user
  and ask them to run `codex login` (suggest they type `! codex login` so it
  runs in this session). Do not try to work around missing auth with the API key
  path unless the user asks.

If Codex is missing or unauthenticated, stop and tell the user exactly what to
run — don't silently fall back or fake an image.

## Generate an image

Use the bundled wrapper — it does the preflight check, runs the handoff with the
right flags, and guarantees the file ends up where you asked (Codex otherwise
saves to `~/.codex/generated_images/`, which is easy to lose):

```bash
scripts/codex_image.sh generate \
  --prompt "a low-poly red fox sitting in snow, soft morning light" \
  --out ./images/fox.png \
  --size 1024x1024 \
  --quality high
```

`--size` and `--quality` are optional (Codex picks sensible defaults). Sizes are
flexible WxH; 1024x1024, 1536x1024, 1024x1536 are the safe standards, up to ~2K
stable / 4K beta. Quality is `low|medium|high`.

### What the wrapper runs (so you understand the handoff)

If you ever need to call Codex directly instead of via the wrapper, this is the
verified invocation:

```bash
codex exec -C "$(pwd)" -s workspace-write --skip-git-repo-check \
  "Use the built-in image generation tool to create <description>. \
   Save the result as an absolute-path PNG at /abs/path/to/out.png. \
   Do not save anywhere else."
```

Why each piece matters:

- **`-C "$(pwd)"`** roots Codex at the current directory so relative save paths
  resolve where you expect.
- **`-s workspace-write`** lets Codex write the file. Without it the tool runs
  but can't save into the project and the image is lost to the default dir.
- **`--skip-git-repo-check`** lets it run outside a git repo (image tasks often
  do).
- **An explicit, absolute save path in the prompt** is the single most important
  detail: if you don't name a path, Codex dumps to `~/.codex/generated_images/`
  and you have to hunt for it. Say the path, say "do not save anywhere else."

Image turns are slow (tens of seconds) and consume plan limits 3–5× faster than
text turns — that's expected, not a hang. Give the call a generous timeout
(≥120s) or run it in the background.

## Edit / transform an existing image

The same built-in tool edits images. Pass the source with `-i` (the wrapper
handles this) and describe the change:

```bash
scripts/codex_image.sh edit \
  --input ./images/fox.png \
  --prompt "make it a watercolor painting, warmer palette" \
  --out ./images/fox_watercolor.png
```

For inpainting (change only part of an image), supply a mask PNG whose
transparent areas mark what to regenerate:

```bash
scripts/codex_image.sh edit \
  --input ./photo.png --mask ./mask.png \
  --prompt "replace the sky with a dramatic sunset" \
  --out ./photo_edited.png
```

Direct form, for reference:

```bash
codex exec -i ./images/fox.png -C "$(pwd)" -s workspace-write --skip-git-repo-check \
  "Edit the attached image: make it a watercolor painting. \
   Save the edited PNG at /abs/path/to/out.png. Do not save anywhere else."
```

## Transparent backgrounds

gpt-image-2 can't emit true transparency directly. The standard workaround is to
generate the subject on a flat chroma-key background and key it out. Pass
`--transparent` and the wrapper instructs Codex to render on `#00ff00` (or
`#ff00ff` when the subject is itself green) and then remove that background,
producing a transparent PNG. This is best-effort — Codex does the keying itself,
so inspect the result; fine hair/edges may need a manual pass. If the user only
needs an opaque asset, skip this.

## After the handoff — verify, don't assume

Codex's final message reports what it did, but always confirm the actual file:

- Check the `--out` path exists and is a non-empty PNG. The wrapper does this and
  relocates the file from `~/.codex/generated_images/` if Codex ignored the path.
- If it's genuinely missing, read Codex's captured output (the wrapper saves it
  to a temp file and prints the path on failure) to see what went wrong — an auth
  error, a refused prompt (content policy), or a rate-limit (IPM cap: new
  accounts start at 5 images/min).
- Report the final saved path to the user. If you can display images in this
  surface, show it; otherwise give the path.

Never claim an image was created without confirming the file is on disk.

## API fallback (only when asked, e.g. large batches)

If the user explicitly wants the raw API — typically to batch many images and
pay per-image API pricing rather than spend subscription limits — Codex can call
`https://api.openai.com/v1/images/generations` (and `/v1/images/edits`) with
`model: gpt-image-2`. This path needs `OPENAI_API_KEY` in the environment, and
note Codex strips secret-named env vars from its shell subprocesses by default,
so you must forward it:

```bash
codex exec -s workspace-write --skip-git-repo-check \
  -c shell_environment_policy.inherit=all \
  -c shell_environment_policy.ignore_default_excludes=true \
  "Call the OpenAI Images API (model gpt-image-2) with prompt '<...>', \
   decode data[0].b64_json, and save to /abs/path/out.png. Use \$OPENAI_API_KEY."
```

The response returns base64 in `data[0].b64_json` (gpt-image models never return
a URL). Prefer the built-in tool unless there's a concrete reason not to.
