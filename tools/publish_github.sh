#!/usr/bin/env bash
# Review the combined v0.6.7–v0.7.2 update paths, then safely push the current main branch.
# Usage: bash tools/publish_github.sh ["commit message"]
# This never stores a token, rewrites your remote, uses force, or pulls for you.
set -euo pipefail
# Git's default pager stopped the previous publisher mid-list on terminals.
# Print directly instead, so the confirmation prompt is always visible.
export GIT_PAGER=cat
export PAGER=cat
cd "$(dirname "${BASH_SOURCE[0]}")/.."
BRANCH="main"
MSG="Apex Assassin v0.7.2: restored enemies and post-win lockers"
CONFIRM=0
for arg in "$@"; do
  case "$arg" in --yes) echo 'This update requires review and confirmation at the prompt; --yes is disabled.' >&2;exit 1;; --help|-h) sed -n '2,4p' "$0";exit 0;; *) MSG="$arg";; esac
done
command -v git >/dev/null || { echo 'Git is required. Install it before publishing.' >&2;exit 1; }
[ -d .git ] || { echo 'This project is not a Git clone. Clone your GitHub project first.' >&2;exit 1; }
[ "$(git branch --show-current)" = "$BRANCH" ] || { echo "Switch to your $BRANCH branch first; this script does not switch branches." >&2;exit 1; }
[ -f tools/v067-update-files.txt ] || { echo 'Update file list is missing; re-run the update installer.' >&2;exit 1; }
[ -f tools/v068-update-files.txt ] || { echo 'v0.6.8 update file list is missing; re-run the update installer.' >&2;exit 1; }
[ -f tools/v069-update-files.txt ] || { echo 'v0.6.9 update file list is missing; re-run the update installer.' >&2;exit 1; }
[ -f tools/v070-update-files.txt ] || { echo 'v0.7.0 update file list is missing; re-run the update installer.' >&2;exit 1; }
[ -f tools/v071-update-files.txt ] || { echo 'v0.7.1 update file list is missing; re-run the update installer.' >&2;exit 1; }
[ -f tools/v072-update-files.txt ] || { echo 'v0.7.2 update file list is missing; re-run the update installer.' >&2;exit 1; }
[ -s assets/audio/ui_tap_audio.mp3 ] || { echo 'Your ui_tap_audio.mp3 is missing. Restore the original installed sound before publishing.' >&2;exit 1; }
[ -s assets/audio/stab.mp3 ] || { echo 'Your stab.mp3 is missing. Install your original Pi Downloads sound first.' >&2;exit 1; }
[ -s assets/audio/suspect.mp3 ] || { echo 'Your suspect.mp3 is missing. Install your original Pi Downloads sound first.' >&2;exit 1; }
[ -s assets/audio/stab2.mp3 ] || { echo 'Your stab2.mp3 is missing. Restore your original installed recording before publishing.' >&2;exit 1; }
[ -s assets/audio/suspect2.mp3 ] || { echo 'Your suspect2.mp3 is missing. Restore your original installed recording before publishing.' >&2;exit 1; }
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
mapfile -t ALL < <(cat tools/v067-update-files.txt tools/v068-update-files.txt tools/v069-update-files.txt tools/v070-update-files.txt tools/v071-update-files.txt tools/v072-update-files.txt)
paths=()
declare -A seen_paths=()
for path in "${ALL[@]}";do
  [ -n "$path" ] || continue
  case "$path" in \#*)continue;; /*|../*|*/../*|assets/audio/*|art_source/*)echo "Unsafe or private path in update list: $path" >&2;exit 1;;esac
  [ -z "${seen_paths[$path]+present}" ] || continue
  seen_paths[$path]=1
  if [ -e "$path" ] || [ -L "$path" ] || git ls-files --error-unmatch -- "$path" >/dev/null 2>&1;then paths+=("$path");fi
done
[ "${#paths[@]}" -gt 0 ] || { echo 'No update files found.' >&2;exit 1; }
# The updater copies these recordings from this Pi; the default publisher
# deliberately leaves them private. Explicit opt-in needs a separate prompt.
case "${APEX_PUBLISH_KEY_SOUNDS:-0}" in
  0) echo 'Key sounds remain private; a GitHub-built APK will omit them unless you explicitly opt in.';;
  1)
    for audio in assets/audio/pickkey.mp3 assets/audio/unlockkey.mp3; do
      [ -f "$audio" ] && [ -s "$audio" ] && [ ! -L "$audio" ] || { echo "Missing or unsafe requested sound: $audio" >&2;exit 1; }
    done
    echo 'WARNING: Both key MP3s will be committed and uploaded to GitHub, including a public repository if your repository is public.'
    sha256sum assets/audio/pickkey.mp3 assets/audio/unlockkey.mp3
    printf 'Upload these two recordings to GitHub? [y/N] '
    read -r sound_answer || sound_answer=''
    case "$sound_answer" in y|Y|yes|YES) paths+=(assets/audio/pickkey.mp3 assets/audio/unlockkey.mp3);; *) echo 'Cancelled before staging any files.';exit 1;; esac
    ;;
  *) echo 'APEX_PUBLISH_KEY_SOUNDS must be 0 or 1.' >&2;exit 1;;
esac
# Other personal recordings and all audio import metadata are intentionally never
# staged by this code-only update, even if the user has modified them locally.
git add -A -- "${paths[@]}"
# Preserve the four supplied map files byte-for-byte. Their upstream blank
# lines/whitespace are covered by source-manifest.sha256 and must not prevent
# a rights-reviewed publication. Check all other staged files normally.
if ! git diff --cached --check -- . \
  ':(exclude)data/source_maps/v70/BossMaps.txt' \
  ':(exclude)data/source_maps/v70/RegularMaps.txt' \
  ':(exclude)data/source_maps/v70/RemoteMaps.txt' \
  ':(exclude)data/source_maps/v70/TutorialMaps.txt';then
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
echo 'WARNING: This may include supplied Hunter Files sprites, maps and recovered configuration, plus selected and earlier artwork.'
echo 'The original reference sheets and older personal recordings are not staged.'
echo 'Other personal recordings and audio import metadata are never staged by this update.'
echo 'Rights are not established. Review ASSETS_LICENSE.md and confirm you have permission to publish these assets and maps.'
sha256sum assets/audio/ui_tap_audio.mp3 assets/audio/stab.mp3 assets/audio/suspect.mp3 assets/audio/stab2.mp3 assets/audio/suspect2.mp3
if [ "$CONFIRM" != 1 ];then
  printf 'Confirm you have publication rights AND commit and push these changes to %s? [y/N] ' "$URL"
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
