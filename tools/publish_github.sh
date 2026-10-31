#!/usr/bin/env bash
# Commit only the v0.6.3 update paths, then safely push the current main branch.
# Usage: bash tools/publish_github.sh ["commit message"] [--yes]
# This never stores a token, rewrites your remote, uses force, or pulls for you.
set -euo pipefail
# Git's default pager stopped the previous publisher mid-list on terminals.
# Print directly instead, so the confirmation prompt is always visible.
export GIT_PAGER=cat
export PAGER=cat
cd "$(dirname "${BASH_SOURCE[0]}")/.."
BRANCH="main"
MSG="Apex Assassin v0.6.3: L cover, diamonds, fast guards and tap audio"
CONFIRM=0
for arg in "$@"; do
  case "$arg" in --yes) CONFIRM=1;; --help|-h) sed -n '2,4p' "$0";exit 0;; *) MSG="$arg";; esac
done
command -v git >/dev/null || { echo 'Git is required. Install it before publishing.' >&2;exit 1; }
[ -d .git ] || { echo 'This project is not a Git clone. Clone your GitHub project first.' >&2;exit 1; }
[ "$(git branch --show-current)" = "$BRANCH" ] || { echo "Switch to your $BRANCH branch first; this script does not switch branches." >&2;exit 1; }
[ -f tools/v063-update-files.txt ] || { echo 'Update file list is missing; re-run the update installer.' >&2;exit 1; }
[ -s assets/audio/ui_tap_audio.mp3 ] || { echo 'Your ui_tap_audio.mp3 is missing. Run the v0.6.3 installer first.' >&2;exit 1; }
if ! git config user.name >/dev/null || ! git config user.email >/dev/null;then
  echo 'Set your Git identity, for example:' >&2
  echo '  git config --global user.name "Your Name"' >&2
  echo '  git config --global user.email "you@example.com"' >&2
  exit 1
fi
if ! git diff --cached --quiet;then
  echo 'The index already contains staged changes. Review and unstage them before running this script.' >&2
  git diff --cached --stat >&2;exit 1
fi
URL=$(git remote get-url origin 2>/dev/null) || { echo 'No origin remote is configured; clone or add your GitHub remote first.' >&2;exit 1; }
case "${URL%.git}" in
  https://github.com/Aryanshahx/apexassassin|ssh://git@github.com/Aryanshahx/apexassassin|git@github.com:Aryanshahx/apexassassin) ;;
  *) if [ "${APEX_ALLOW_OTHER_ORIGIN:-0}" != 1 ];then
       echo "Unexpected origin: $URL" >&2
       echo 'If this is deliberately your fork, set APEX_ALLOW_OTHER_ORIGIN=1 and retry.' >&2;exit 1
     fi;;
esac
printf 'Fetching %s from %s...\n' "$BRANCH" "$URL"
if ! git fetch --no-tags origin "$BRANCH";then
  echo 'Fetch failed. Check network access and GitHub authentication; nothing was staged or committed.' >&2;exit 1
fi
REMOTE_TIP=$(git rev-parse FETCH_HEAD)
if ! git merge-base --is-ancestor "$REMOTE_TIP" HEAD;then
  echo "Remote $BRANCH has commits not in your current branch. Update/rebase safely first, then rerun." >&2
  echo 'Your files and index were not changed by this script.' >&2;exit 1
fi
mapfile -t ALL < tools/v063-update-files.txt
paths=()
for path in "${ALL[@]}";do
  [ -n "$path" ] || continue
  case "$path" in \#*)continue;; /*|../*|*/../*)echo "Unsafe path in update list: $path" >&2;exit 1;;esac
  if [ -e "$path" ] || [ -L "$path" ] || git ls-files --error-unmatch -- "$path" >/dev/null 2>&1;then paths+=("$path");fi
done
[ "${#paths[@]}" -gt 0 ] || { echo 'No update files found.' >&2;exit 1; }
git add -A -- "${paths[@]}"
if ! git diff --cached --check;then
  git reset -q HEAD -- "${paths[@]}" || true
  echo 'Whitespace checks failed; update paths were unstaged.' >&2;exit 1
fi
LOCAL_COMMITS=$(git rev-list --count "$REMOTE_TIP..HEAD")
if git diff --cached --quiet && [ "$LOCAL_COMMITS" = 0 ];then
  echo 'Nothing to commit or push.';exit 0
fi
echo
echo 'Staged update paths:'
git diff --cached --stat
echo "Existing local commits that would also be pushed: $LOCAL_COMMITS"
if [ "$LOCAL_COMMITS" -gt 0 ];then git log --oneline "$REMOTE_TIP..HEAD";fi
echo 'Review ASSETS_LICENSE.md and confirm you have rights to publish the artwork and your tap audio.'
if [ "$CONFIRM" != 1 ];then
  printf 'Commit and push the listed changes to %s? [y/N] ' "$URL"
  read -r answer || answer=''
  case "$answer" in y|Y|yes|YES) ;; *)
    git reset -q HEAD -- "${paths[@]}" || true
    echo 'Cancelled. Update paths were unstaged; working files were kept.';exit 1;;
  esac
fi
if ! git diff --cached --quiet;then git commit -m "$MSG";fi
if ! git push -u origin "HEAD:refs/heads/$BRANCH";then
  echo 'Push failed; any new commit remains safely on your local branch. Check credentials or remote changes, then retry.' >&2;exit 1
fi
echo 'Pushed successfully. GitHub Actions can build the debug APK.'
