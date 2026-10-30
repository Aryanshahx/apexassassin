#!/usr/bin/env bash
# Commit + push Apex Assassin to GitHub. GitHub Actions then builds the debug APK.
# Usage: bash tools/publish_github.sh ["commit message"]
set -euo pipefail
cd "$(dirname "${BASH_SOURCE[0]}")/.."
REMOTE="https://github.com/Aryanshahx/apexassassin.git"
BRANCH="main"
MSG="${1:-Apex Assassin v0.3: original characters, animations, stealth gameplay, Android CI}"

if ! command -v git >/dev/null 2>&1; then
  echo "git is required: sudo apt install git" >&2; exit 1
fi
if [ ! -d .git ]; then git init -b "$BRANCH"; fi
if git remote get-url origin >/dev/null 2>&1; then
  git remote set-url origin "$REMOTE"
else
  git remote add origin "$REMOTE"
fi
if ! git config user.name >/dev/null 2>&1 || ! git config user.email >/dev/null 2>&1; then
  echo "Set your Git identity first:" >&2
  echo '  git config --global user.name "Your Name"' >&2
  echo '  git config --global user.email "you@example.com"' >&2
  exit 1
fi
git add -A
if git diff --cached --quiet; then
  echo "No changes to commit."
else
  git commit -m "$MSG"
fi
git fetch origin "$BRANCH" || true
if git rev-parse --verify "origin/$BRANCH" >/dev/null 2>&1; then
  if ! git merge-base --is-ancestor "origin/$BRANCH" HEAD; then
    echo "Remote has commits you do not have. Run: git pull --rebase origin $BRANCH" >&2
    exit 1
  fi
fi
git push -u origin "$BRANCH"
echo
echo "Pushed. Open: https://github.com/Aryanshahx/apexassassin/actions"
echo "Download the artifact: apex-assassin-debug-<sha>"
