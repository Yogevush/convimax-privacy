#!/usr/bin/env bash
# upscale.sh - command-line front end for Upscayl's local AI engine (upscayl-bin).
# Part of the "upscayl" Claude Code skill.
#
# Creates NEW files only. Originals are never modified or deleted.
#
# Verified against Upscayl 2.15.0: the help text of the bundled upscayl-bin and
# the app's own argument builder (electron/utils/get-arguments.ts).
# Written for macOS /bin/bash 3.2 compatibility (no bash 4 features).

set -euo pipefail

SCRIPT_VERSION="1.0.0"
DEFAULT_MODEL="upscayl-standard-4x"

MODEL="${UPSCAYL_MODEL:-$DEFAULT_MODEL}"
SCALE=4
FORMAT=""
WIDTH=""
COMPRESS=0
OUT_DIR=""
SUFFIX=""
SUFFIX_SET=0
OVERWRITE=0
RECURSIVE=0
TTA=0
TILE=""
GPU_ID=""
DRY_RUN=0
VERBOSE=0
ACTION="run"
INPUTS=()

OK_COUNT=0
SKIP_COUNT=0
FAIL_COUNT=0

usage() {
  cat <<'EOF'
upscale.sh - enlarge images with Upscayl's local AI engine (runs on this Mac, offline).

Usage:
  upscale.sh [options] <image-or-folder> [more images or folders...]
  upscale.sh --check          # verify Upscayl is installed and print paths
  upscale.sh --list-models    # print the available models

Options:
  -m, --model NAME     Model (default: upscayl-standard-4x). See --list-models.
  -s, --scale N        Output scale: 2, 3 or 4 (default: 4).
  -f, --format EXT     Output format: jpg, png or webp (default: same as the input).
  -w, --width PX       Resize the result to this width in pixels (keeps aspect ratio).
                       When given, --scale is ignored (same behaviour as the app).
  -c, --compress N     0-100 (default: 0 = best quality). For jpg/webp: quality = 100 - N.
  -o, --out DIR        Output folder (default: an "upscaled" folder next to each input).
      --suffix TEXT    Suffix for output names (default: _upscayl_<scale>x).
      --overwrite      Overwrite outputs that already exist (default: skip them).
      --recursive      When given a folder, also process its sub-folders.
      --tta            TTA mode: slower, slightly better quality.
      --tile N         Tile size (default: auto). Try 256 or 128 on out-of-memory errors.
      --gpu ID         GPU id (default: auto). Only relevant on multi-GPU machines.
      --dry-run        Print the engine commands instead of running them.
  -v, --verbose        Show the engine's own progress output.
  -h, --help           This help.

Examples:
  upscale.sh photo.jpg                      -> photo/upscaled/photo_upscayl_4x.jpg
  upscale.sh --scale 2 ~/Pictures/products  -> every jpg/png/webp in the folder, 2x
  upscale.sh --width 2000 --format jpg *.png -> 2000 px wide jpg files

Environment:
  UPSCAYL_BIN     Path to upscayl-bin (default: inside /Applications/Upscayl.app).
  UPSCAYL_MODELS  Path to the models folder (default: next to the binary).
  UPSCAYL_MODEL   Default model name.
EOF
}

log() { printf '%s\n' "$*" >&2; }
die() { printf 'Error: %s\n' "$*" >&2; exit 1; }
lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# ---------------------------------------------------------------- arguments
need_value() { [[ $# -ge 2 ]] || die "$1 needs a value (see --help)"; }

while [[ $# -gt 0 ]]; do
  case "$1" in
    -m|--model)    need_value "$@"; MODEL="$2"; shift 2 ;;
    -s|--scale)    need_value "$@"; SCALE="$2"; shift 2 ;;
    -f|--format)   need_value "$@"; FORMAT="$2"; shift 2 ;;
    -w|--width)    need_value "$@"; WIDTH="$2"; shift 2 ;;
    -c|--compress) need_value "$@"; COMPRESS="$2"; shift 2 ;;
    -o|--out)      need_value "$@"; OUT_DIR="$2"; shift 2 ;;
    --suffix)      need_value "$@"; SUFFIX="$2"; SUFFIX_SET=1; shift 2 ;;
    --tile)        need_value "$@"; TILE="$2"; shift 2 ;;
    --gpu)         need_value "$@"; GPU_ID="$2"; shift 2 ;;
    --overwrite)   OVERWRITE=1; shift ;;
    --recursive)   RECURSIVE=1; shift ;;
    --tta)         TTA=1; shift ;;
    --dry-run)     DRY_RUN=1; shift ;;
    -v|--verbose)  VERBOSE=1; shift ;;
    --list-models) ACTION="list-models"; shift ;;
    --check)       ACTION="check"; shift ;;
    --version)     echo "upscale.sh $SCRIPT_VERSION"; exit 0 ;;
    -h|--help)     usage; exit 0 ;;
    --)            shift; while [[ $# -gt 0 ]]; do INPUTS+=("$1"); shift; done ;;
    -*)            die "Unknown option: $1 (see --help)" ;;
    *)             INPUTS+=("$1"); shift ;;
  esac
done

case "$SCALE" in
  2|3|4) ;;
  *) die "--scale must be 2, 3 or 4 (got: $SCALE)" ;;
esac

if [[ -n "$FORMAT" ]]; then
  FORMAT="$(lower "$FORMAT")"
  case "$FORMAT" in
    jpeg) FORMAT="jpg" ;;
    jpg|png|webp) ;;
    *) die "--format must be jpg, png or webp (got: $FORMAT)" ;;
  esac
fi

if ! [[ "$COMPRESS" =~ ^[0-9]+$ ]] || [[ "$COMPRESS" -gt 100 ]]; then
  die "--compress must be a whole number between 0 and 100 (got: $COMPRESS)"
fi
if [[ -n "$WIDTH" ]] && ! [[ "$WIDTH" =~ ^[0-9]+$ && "$WIDTH" -gt 0 ]]; then
  die "--width must be a positive number of pixels (got: $WIDTH)"
fi
if [[ -n "$TILE" ]] && ! [[ "$TILE" =~ ^[0-9]+$ ]]; then
  die "--tile must be a whole number (got: $TILE)"
fi
if [[ -n "$GPU_ID" ]] && ! [[ "$GPU_ID" =~ ^[0-9]+$ ]]; then
  die "--gpu must be a whole number (got: $GPU_ID)"
fi

# ---------------------------------------------------------------- locate Upscayl
INSTALL_HINT="Upscayl is not installed on this Mac (looked for /Applications/Upscayl.app/Contents/Resources/bin/upscayl-bin).
Install it with:   brew install --cask upscayl
or download it from https://upscayl.org and drag Upscayl into Applications.
If it is installed somewhere else, set UPSCAYL_BIN=/path/to/upscayl-bin."

find_bin() {
  local c
  local candidates=()
  if [[ -n "${UPSCAYL_BIN:-}" ]]; then
    candidates+=("$UPSCAYL_BIN")
  fi
  candidates+=(
    "/Applications/Upscayl.app/Contents/Resources/bin/upscayl-bin"
    "/Applications/Upscayl.app/Contents/resources/bin/upscayl-bin"
    "$HOME/Applications/Upscayl.app/Contents/Resources/bin/upscayl-bin"
    "$HOME/Applications/Upscayl.app/Contents/resources/bin/upscayl-bin"
  )
  # Spotlight fallback: the app was installed in a non-standard folder.
  if command -v mdfind >/dev/null 2>&1; then
    local app
    while IFS= read -r app; do
      if [[ -n "$app" ]]; then
        candidates+=("$app/Contents/Resources/bin/upscayl-bin" "$app/Contents/resources/bin/upscayl-bin")
      fi
    done < <(mdfind "kMDItemCFBundleIdentifier == 'org.upscayl.Upscayl'" 2>/dev/null || true)
  fi
  # A standalone upscayl-bin on PATH (Linux, or a manual install).
  if command -v upscayl-bin >/dev/null 2>&1; then
    candidates+=("$(command -v upscayl-bin)")
  fi
  for c in "${candidates[@]}"; do
    if [[ -f "$c" && -x "$c" ]]; then
      printf '%s\n' "$c"
      return 0
    fi
  done
  return 1
}

find_models_dir() {
  local bin_dir
  bin_dir="$(cd "$(dirname "$1")" && pwd -P)"
  local d
  for d in "${UPSCAYL_MODELS:-}" "$bin_dir/../models" "$bin_dir/models"; do
    if [[ -n "$d" && -d "$d" ]]; then
      (cd "$d" && pwd -P)
      return 0
    fi
  done
  return 1
}

list_models() {
  local p
  for p in "$MODELS_DIR"/*.param; do
    [[ -e "$p" ]] || continue
    p="$(basename "$p")"
    printf '%s\n' "${p%.param}"
  done
}

# Same rule as the Upscayl app (common/check-model-scale.ts): the model's own
# scale is read from its name; anything else counts as 4x.
model_scale() {
  local n
  n="$(lower "$1")"
  if [[ "$n" == *x2* || "$n" == *2x* ]]; then
    echo 2
  elif [[ "$n" == *x3* || "$n" == *3x* ]]; then
    echo 3
  else
    echo 4
  fi
}

BIN=""
if ! BIN="$(find_bin)"; then
  log "$INSTALL_HINT"
  exit 2
fi
MODELS_DIR=""
if ! MODELS_DIR="$(find_models_dir "$BIN")"; then
  die "Found the engine at $BIN but no models folder next to it. Set UPSCAYL_MODELS=/path/to/models."
fi

if [[ "$ACTION" == "list-models" ]]; then
  list_models
  exit 0
fi

if [[ "$ACTION" == "check" ]]; then
  APP_DIR="$(cd "$(dirname "$BIN")/../../.." 2>/dev/null && pwd -P || true)"
  echo "Engine:  $BIN"
  if [[ -n "$APP_DIR" && -f "$APP_DIR/Contents/Info.plist" ]] && command -v defaults >/dev/null 2>&1; then
    app_version="$(defaults read "$APP_DIR/Contents/Info" CFBundleShortVersionString 2>/dev/null || true)"
    echo "App:     $APP_DIR${app_version:+ (version $app_version)}"
  fi
  echo "Models:  $MODELS_DIR"
  echo "Available models:"
  list_models | sed 's/^/  - /'
  # upscayl-bin exits with a non-zero code after printing its help, so only the text is checked.
  help_text="$("$BIN" -h 2>&1 || true)"
  if printf '%s\n' "$help_text" | grep -q 'Usage: upscayl-bin'; then
    echo "Engine responds: yes"
    if [[ -n "$APP_DIR" && -d "$APP_DIR" ]] && command -v xattr >/dev/null 2>&1 \
       && xattr -p com.apple.quarantine "$APP_DIR" >/dev/null 2>&1; then
      echo "Note: the app still carries the macOS quarantine flag (fresh download)."
      echo "      If the first real run is blocked, open the app once (open -a Upscayl) or run:"
      echo "      xattr -dr com.apple.quarantine \"$APP_DIR\""
    fi
    echo "OK: Upscayl is installed and ready."
    exit 0
  fi
  echo "Engine responds: NO. The binary exists but could not run."
  echo "On a Mac this is usually Gatekeeper on a fresh install: open the app once (open -a Upscayl),"
  echo "or run: xattr -dr com.apple.quarantine /Applications/Upscayl.app"
  exit 3
fi

# ---------------------------------------------------------------- inputs
if [[ ${#INPUTS[@]} -eq 0 ]]; then
  usage
  exit 1
fi

if [[ ! -f "$MODELS_DIR/$MODEL.param" || ! -f "$MODELS_DIR/$MODEL.bin" ]]; then
  die "Model '$MODEL' not found in $MODELS_DIR. Available: $(list_models | tr '\n' ' ')"
fi

is_image() {
  local e
  e="$(lower "${1##*.}")"
  case "$e" in
    jpg|jpeg|png|webp) return 0 ;;
    *) return 1 ;;
  esac
}

FILES=()
MISSING=0
for p in "${INPUTS[@]}"; do
  if [[ -d "$p" ]]; then
    if [[ $RECURSIVE -eq 1 ]]; then
      while IFS= read -r -d '' f; do
        FILES+=("$f")
      done < <(find "$p" -type d -name upscaled -prune -o -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 | sort -z)
    else
      while IFS= read -r -d '' f; do
        FILES+=("$f")
      done < <(find "$p" -maxdepth 1 -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print0 | sort -z)
    fi
  elif [[ -f "$p" ]]; then
    if is_image "$p"; then
      FILES+=("$p")
    else
      log "Skipping (only jpg, png and webp are supported): $p"
      SKIP_COUNT=$((SKIP_COUNT + 1))
    fi
  else
    log "Not found: $p"
    MISSING=1
  fi
done

if [[ ${#FILES[@]} -eq 0 ]]; then
  die "No jpg, png or webp images to process."
fi

# ---------------------------------------------------------------- helpers
image_size() {
  # Prints "WxH" when a tool is available, otherwise nothing.
  if command -v sips >/dev/null 2>&1; then
    sips -g pixelWidth -g pixelHeight "$1" 2>/dev/null | awk '/pixelWidth/{w=$2} /pixelHeight/{h=$2} END{if (w && h) print w "x" h}'
  elif command -v identify >/dev/null 2>&1; then
    identify -format '%wx%h' "$1" 2>/dev/null || true
  fi
}

file_size_kb() {
  local bytes
  bytes="$(wc -c < "$1" | tr -d ' ')"
  echo $(( (bytes + 1023) / 1024 ))
}

failure_hint() {
  # $1 = exit code, $2 = log file. Uses grep -E so it also works with macOS (BSD) grep.
  if grep -qiE 'Invalid GPU Device|vulkan' "$2" 2>/dev/null; then
    log "Hint: the engine needs a GPU with Vulkan/Metal. On a Mac this should not happen; on a server or VM without a GPU the engine cannot run."
  fi
  if grep -qiE 'vkAllocateMemory|vkQueueSubmit|out of memory|DEVICE_LOST' "$2" 2>/dev/null; then
    log "Hint: the image is too large for the GPU memory. Retry with --tile 256 (or --tile 128)."
  fi
  if [[ "$1" -eq 137 || "$1" -eq 126 ]] || grep -qiE 'Operation not permitted|Killed' "$2" 2>/dev/null; then
    log "Hint: macOS may be blocking the binary (Gatekeeper). Open the app once (open -a Upscayl) or run: xattr -dr com.apple.quarantine /Applications/Upscayl.app"
  fi
  if grep -qiE 'Invalid output path extension|Invalid format' "$2" 2>/dev/null; then
    log "Hint: only jpg, png and webp are supported. Convert other formats first, e.g.: sips -s format jpeg photo.heic --out photo.jpg"
  fi
}

# ---------------------------------------------------------------- run
MODEL_SCALE="$(model_scale "$MODEL")"

run_one() {
  local in="$1"
  local base name ext outext outdir suffix outfile
  base="$(basename "$in")"
  name="${base%.*}"
  ext="$(lower "${base##*.}")"
  if [[ "$ext" == "jpeg" ]]; then ext="jpg"; fi
  outext="${FORMAT:-$ext}"

  if [[ -n "$OUT_DIR" ]]; then
    outdir="$OUT_DIR"
  else
    outdir="$(dirname "$in")/upscaled"
  fi
  if [[ $SUFFIX_SET -eq 1 ]]; then
    suffix="$SUFFIX"
  else
    suffix="_upscayl_${SCALE}x"
  fi
  outfile="$outdir/${name}${suffix}.${outext}"

  if [[ -e "$outfile" && $OVERWRITE -eq 0 ]]; then
    log "= skipped (already exists, use --overwrite to redo): $outfile"
    SKIP_COUNT=$((SKIP_COUNT + 1))
    return 0
  fi

  # Mirrors the argument order the Upscayl app itself uses.
  local args=(-i "$in" -o "$outfile" -m "$MODELS_DIR" -n "$MODEL" -f "$outext" -c "$COMPRESS")
  if [[ -n "$WIDTH" ]]; then
    args+=(-w "$WIDTH")
  elif [[ "$SCALE" != "$MODEL_SCALE" ]]; then
    args+=(-s "$SCALE")
  fi
  if [[ -n "$TILE" ]]; then args+=(-t "$TILE"); fi
  if [[ -n "$GPU_ID" ]]; then args+=(-g "$GPU_ID"); fi
  if [[ $TTA -eq 1 ]]; then args+=(-x); fi
  if [[ $VERBOSE -eq 1 ]]; then args+=(-v); fi

  if [[ $DRY_RUN -eq 1 ]]; then
    printf '%q ' "$BIN" "${args[@]}"
    printf '\n'
    return 0
  fi

  mkdir -p "$outdir"
  local logf rc=0
  logf="$(mktemp "${TMPDIR:-/tmp}/upscayl.XXXXXX")"
  local started
  started="$(date +%s)"
  if [[ $VERBOSE -eq 1 ]]; then
    "$BIN" "${args[@]}" 2> >(tee "$logf" >&2) || rc=$?
  else
    "$BIN" "${args[@]}" >/dev/null 2>"$logf" || rc=$?
  fi
  local secs=$(( $(date +%s) - started ))

  # Same success rule as the app: exit code 0, no "Error"/"failed" in the engine output,
  # and a non-empty output file.
  if [[ $rc -eq 0 ]] && ! grep -qE 'Error|failed' "$logf" && [[ -s "$outfile" ]]; then
    local dims
    dims="$(image_size "$outfile")"
    log "+ $in  ->  $outfile  (${dims:-done}, $(file_size_kb "$outfile") KB, ${secs}s)"
    OK_COUNT=$((OK_COUNT + 1))
    rm -f "$logf"
    return 0
  fi

  FAIL_COUNT=$((FAIL_COUNT + 1))
  log "x FAILED: $in (exit code $rc)"
  if [[ -s "$logf" ]]; then
    grep -v '^[0-9.]*%$' "$logf" | tail -n 12 | sed 's/^/    | /' >&2
  fi
  failure_hint "$rc" "$logf"
  rm -f "$logf"
  if [[ -e "$outfile" && ! -s "$outfile" ]]; then rm -f "$outfile"; fi
  return 0
}

if [[ -n "$WIDTH" ]]; then
  SCALE_DESC="width $WIDTH px"
else
  SCALE_DESC="${SCALE}x"
fi
log "Upscayl engine: $BIN"
log "Model: $MODEL | scale: $SCALE_DESC | format: ${FORMAT:-same as input} | compress: $COMPRESS | files: ${#FILES[@]}"
for f in "${FILES[@]}"; do
  run_one "$f"
done

if [[ $DRY_RUN -eq 1 ]]; then
  exit 0
fi

log ""
log "Done. succeeded: $OK_COUNT | skipped: $SKIP_COUNT | failed: $FAIL_COUNT"
if [[ $FAIL_COUNT -gt 0 || $MISSING -eq 1 ]]; then
  exit 1
fi
exit 0
