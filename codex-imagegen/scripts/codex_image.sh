#!/usr/bin/env bash
# Hand off image generation/editing to the Codex CLI's built-in image tool
# (gpt-image-2, on the user's ChatGPT subscription). Guarantees the output file
# lands at --out even though Codex defaults to ~/.codex/generated_images/.
#
# Usage:
#   codex_image.sh generate --prompt TEXT --out PATH [--size WxH] [--quality low|medium|high] [--transparent]
#   codex_image.sh edit --input PATH [--mask PATH] --prompt TEXT --out PATH [--transparent]
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }

mode="${1:-}"; shift || true
[[ "$mode" == "generate" || "$mode" == "edit" ]] || die "first arg must be 'generate' or 'edit'"

prompt="" out="" size="" quality="" input="" mask="" transparent=0
while [[ $# -gt 0 ]]; do
  case "$1" in
    --prompt) prompt="$2"; shift 2;;
    --out) out="$2"; shift 2;;
    --size) size="$2"; shift 2;;
    --quality) quality="$2"; shift 2;;
    --input) input="$2"; shift 2;;
    --mask) mask="$2"; shift 2;;
    --transparent) transparent=1; shift;;
    *) die "unknown flag: $1";;
  esac
done

[[ -n "$prompt" ]] || die "--prompt is required"
[[ -n "$out" ]] || die "--out is required"
[[ "$mode" == "edit" && -z "$input" ]] && die "edit mode requires --input"
[[ -n "$input" && ! -f "$input" ]] && die "input image not found: $input"
[[ -n "$mask" && ! -f "$mask" ]] && die "mask not found: $mask"

# Preflight: Codex must be installed. Auth is checked implicitly (codex exec
# fails loudly with an auth error if not logged in).
command -v codex >/dev/null 2>&1 || die "codex CLI not found. Install: 'npm i -g @openai/codex' or 'brew install --cask codex', then run 'codex login'."

# Resolve an absolute output path and make sure its directory exists, so we can
# tell Codex exactly where to write and later verify it.
mkdir -p "$(dirname "$out")"
abs_out="$(cd "$(dirname "$out")" && pwd)/$(basename "$out")"

# Build the instruction to Codex. The explicit absolute path + "do not save
# anywhere else" is what keeps the file out of the default generated_images dir.
instr=""
if [[ "$mode" == "generate" ]]; then
  instr="Use the built-in image generation tool to create the following image: ${prompt}."
else
  instr="Edit the attached image. Change: ${prompt}."
  [[ -n "$mask" ]] && instr="${instr} A mask is attached; regenerate only the transparent regions of the mask."
fi
[[ -n "$size" ]]    && instr="${instr} Size: ${size}."
[[ -n "$quality" ]] && instr="${instr} Quality: ${quality}."
if [[ "$transparent" == "1" ]]; then
  instr="${instr} gpt-image-2 cannot output transparency directly, so render the subject on a solid flat #00ff00 chroma-key background (use #ff00ff if the subject is predominantly green), then remove that background to produce a genuinely transparent PNG."
fi
instr="${instr} Save the result as a PNG at the absolute path ${abs_out}. Do not save it anywhere else."

# Assemble codex exec args. -i attaches source/mask images (edit mode).
args=(exec -C "$(pwd)" -s workspace-write --skip-git-repo-check)
[[ -n "$input" ]] && args+=(-i "$input")
[[ -n "$mask" ]]  && args+=(-i "$mask")

log="$(mktemp -t codex_image.XXXXXX.log)"
echo "→ handing off to codex ($mode)…" >&2
if ! codex "${args[@]}" "$instr" >"$log" 2>&1; then
  echo "codex exec failed. output:" >&2
  cat "$log" >&2
  die "codex handoff failed (see output above). If it's an auth error, run 'codex login'."
fi

# Verify the file landed at abs_out. If Codex ignored the path and dropped it in
# the default dir, relocate the newest image from there.
if [[ ! -s "$abs_out" ]]; then
  gen_dir="${CODEX_HOME:-$HOME/.codex}/generated_images"
  newest="$(ls -t "$gen_dir"/*.png 2>/dev/null | head -1 || true)"
  if [[ -n "$newest" && -s "$newest" ]]; then
    mv "$newest" "$abs_out"
    echo "note: relocated image from $gen_dir to requested path" >&2
  fi
fi

[[ -s "$abs_out" ]] || { echo "codex output:" >&2; cat "$log" >&2; die "no image produced at $abs_out (see codex output above)."; }

rm -f "$log"
echo "$abs_out"
