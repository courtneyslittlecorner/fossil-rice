#!/usr/bin/env bash
# Copy the live theming into this repo, commit, and push.
# Usage: rice-sync ["commit message"]
#        rice-sync --dry-run      (show what would change, touch nothing)
set -euo pipefail

REPO="$HOME/fossil-rice"
dry=""
[[ "${1:-}" == "--dry-run" || "${1:-}" == "-n" ]] && { dry="--dry-run"; shift; }
msg="${1:-Sync theming $(date '+%Y-%m-%d %H:%M')}"

# source -> folder in the repo
pairs=(
  "$HOME/.config/hypr/                   hypr/"
  "$HOME/.config/quickshell/             quickshell/"
  "$HOME/.config/quickshell-screensaver/ quickshell-screensaver/"
  "$HOME/.config/kitty/                  kitty/"
  "$HOME/.config/mako/                   mako/"
  "$HOME/.local/share/icons/             icons/"
)

# Never copied: backups, bytecode, and the file that holds the weather API key.
# Protected from --delete: repo-only files that have no live counterpart.
excludes=(
  --exclude='*.bak' --exclude='*.pre-*' --exclude='*.auto-attempt'
  --exclude='__pycache__/' --exclude='*.pyc'
  --exclude='/settings.json' --exclude='/.qmlls.ini'
  --filter='protect /settings.example.json'
)

cd "$REPO"
for p in "${pairs[@]}"; do
  read -r src dst <<<"$p"
  [[ -d "$src" ]] || { echo "skip (missing): $src"; continue; }
  rsync -a --delete $dry "${excludes[@]}" ${dry:+--itemize-changes} "$src" "$dst"
done
[[ -f "$HOME/.gtkrc-2.0" ]] && rsync -a $dry ${dry:+--itemize-changes} "$HOME/.gtkrc-2.0" gtk/

[[ -n "$dry" ]] && { echo "(dry run — nothing copied or committed)"; exit 0; }

git add -A
git add -f quickshell/widgets.json quickshell/favoriteapps.json 2>/dev/null || true

# Safety net: refuse to push anything that looks like a filled-in API key.
if git diff --cached -U0 | grep -qE '^\+.*"apiKey"\s*:\s*"[^"]+'; then
  echo "ABORT: an apiKey value is staged. Run 'git -C $REPO reset' and check." >&2
  exit 1
fi

if git diff --cached --quiet; then
  echo "Nothing changed — repo already matches your setup."
  exit 0
fi

git diff --cached --stat | tail -1
git commit -q -m "$msg"
git push -q
echo "Pushed: $(git log -1 --format='%h %s')"
