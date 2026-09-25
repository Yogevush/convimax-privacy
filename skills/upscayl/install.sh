#!/usr/bin/env bash
# install.sh - installs the "upscayl" skill for Claude Code on this Mac.
#
# Run it in one of two ways:
#   1. From a checkout of the repository:   bash skills/upscayl/install.sh
#   2. Standalone, without cloning anything:
#      curl -fsSL https://raw.githubusercontent.com/yogevush/convimax-privacy/main/skills/upscayl/install.sh | bash
#
# Add --with-app to also install the Upscayl app through Homebrew when it is missing.
#
# What it does:
#   - copies SKILL.md and scripts/upscale.sh into ~/.claude/skills/upscayl/
#   - checks that the Upscayl app (and its engine) is installed
# It never touches anything else.

set -euo pipefail

DEST="${CLAUDE_SKILLS_DIR:-$HOME/.claude/skills}/upscayl"
WITH_APP=0

# Branch first (where the skill was developed), then main after it is merged.
RAW_BASES=(
  "${UPSCAYL_SKILL_RAW_BASE:-}"
  "https://raw.githubusercontent.com/yogevush/convimax-privacy/claude/brave-gates-87f3c3/skills/upscayl"
  "https://raw.githubusercontent.com/yogevush/convimax-privacy/main/skills/upscayl"
)

for a in "$@"; do
  case "$a" in
    --with-app) WITH_APP=1 ;;
    -h|--help)
      sed -n '2,14p' "$0" 2>/dev/null || true
      exit 0 ;;
    *) printf 'Unknown option: %s\n' "$a" >&2; exit 1 ;;
  esac
done

# If this script sits inside the skill folder, copy from there; otherwise download.
SRC=""
if [[ -n "${BASH_SOURCE[0]:-}" && -f "${BASH_SOURCE[0]}" ]]; then
  SRC="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd -P)"
  if [[ ! -f "$SRC/SKILL.md" || ! -f "$SRC/scripts/upscale.sh" ]]; then
    SRC=""
  fi
fi

mkdir -p "$DEST/scripts"

if [[ -n "$SRC" ]]; then
  cp "$SRC/SKILL.md" "$DEST/SKILL.md"
  cp "$SRC/scripts/upscale.sh" "$DEST/scripts/upscale.sh"
  echo "Copied the skill from $SRC"
else
  downloaded=0
  for base in "${RAW_BASES[@]}"; do
    [[ -n "$base" ]] || continue
    if curl -fsSL "$base/SKILL.md" -o "$DEST/SKILL.md.tmp" \
       && curl -fsSL "$base/scripts/upscale.sh" -o "$DEST/scripts/upscale.sh.tmp"; then
      mv "$DEST/SKILL.md.tmp" "$DEST/SKILL.md"
      mv "$DEST/scripts/upscale.sh.tmp" "$DEST/scripts/upscale.sh"
      echo "Downloaded the skill from $base"
      downloaded=1
      break
    fi
  done
  rm -f "$DEST/SKILL.md.tmp" "$DEST/scripts/upscale.sh.tmp"
  if [[ $downloaded -eq 0 ]]; then
    echo "Could not download the skill files. Check the internet connection and try again." >&2
    exit 1
  fi
fi

chmod +x "$DEST/scripts/upscale.sh"
echo "Skill installed: $DEST"
echo

check_rc=0
bash "$DEST/scripts/upscale.sh" --check || check_rc=$?

if [[ $check_rc -eq 0 ]]; then
  echo
  echo "All set. In Claude Code on this Mac you can now say, for example:"
  echo "  \"Upscale all the images in ~/Pictures/products 4x\""
  exit 0
fi

echo
if [[ $check_rc -eq 3 ]]; then
  # The app is there but macOS has not let the engine run yet (Gatekeeper on a fresh install).
  echo "The skill is installed and the Upscayl app was found, but macOS has not cleared its engine yet."
  echo "Open the app once (open -a Upscayl), close it, then run:"
  echo "  bash \"$DEST/scripts/upscale.sh\" --check"
  exit 3
fi

if [[ $WITH_APP -eq 1 ]]; then
  if command -v brew >/dev/null 2>&1; then
    echo "Installing the Upscayl app with Homebrew..."
    brew install --cask upscayl
    echo
    check_rc=0
    bash "$DEST/scripts/upscale.sh" --check || check_rc=$?
    exit "$check_rc"
  fi
  echo "Homebrew is not installed, so the app could not be installed automatically." >&2
fi

echo "The skill is installed, but the Upscayl app is missing. Install it with:"
echo "  brew install --cask upscayl"
echo "or download it from https://upscayl.org and drag Upscayl into Applications."
echo "Then run:  bash \"$DEST/scripts/upscale.sh\" --check"
exit 2
