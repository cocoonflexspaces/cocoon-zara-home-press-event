#!/usr/bin/env bash
# ─────────────────────────────────────────────────────────────────────
# deploy.sh — push this Cocoon proposal deck to GitHub Pages
# ─────────────────────────────────────────────────────────────────────

set -euo pipefail
cd "$(dirname "$0")"

# Default repo name: derived from the folder name (e.g., "cocoon-reolink-casa-ezra")
FOLDER_NAME="$(basename "$(pwd)")"
DEFAULT_REPO_NAME="cocoon-${FOLDER_NAME}"

if ! command -v gh >/dev/null 2>&1; then
  echo "✗ gh CLI not installed."
  echo "  Install:  brew install gh"
  echo "  Then:     gh auth login   (pick 'Login with a web browser')"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "✗ gh CLI is not authenticated."
  echo "  Run:  gh auth login"
  exit 1
fi

read -rp "Repository name [${DEFAULT_REPO_NAME}]: " REPO_NAME
REPO_NAME="${REPO_NAME:-$DEFAULT_REPO_NAME}"

if [ ! -d .git ]; then
  echo "→ Initializing git repo…"
  git init -q
  git checkout -b main 2>/dev/null || git checkout main
fi

echo "→ Staging files…"
git add -A
if ! git diff --cached --quiet; then
  git commit -q -m "Cocoon proposal — ${FOLDER_NAME}"
fi

GH_USER="$(gh api user --jq .login)"
echo "→ Creating GitHub repo:  ${GH_USER}/${REPO_NAME}  (private)"
if gh repo view "${GH_USER}/${REPO_NAME}" >/dev/null 2>&1; then
  echo "  Repo already exists — reusing."
else
  gh repo create "${REPO_NAME}" --private --source=. --remote=origin --push -y
fi

if ! git remote get-url origin >/dev/null 2>&1; then
  git remote add origin "https://github.com/${GH_USER}/${REPO_NAME}.git"
fi

echo "→ Pushing to main…"
git push -u origin main -q

echo "→ Enabling GitHub Pages…"
VISIBILITY="$(gh repo view "${GH_USER}/${REPO_NAME}" --json visibility --jq .visibility)"
if [ "$VISIBILITY" = "PRIVATE" ]; then
  read -rp "  GitHub Pages requires a public repo on free plans. Make this repo public? [y/N] " MK
  if [[ "$MK" =~ ^[Yy]$ ]]; then
    gh repo edit "${GH_USER}/${REPO_NAME}" --visibility public --accept-visibility-change-consequences
  else
    echo "  Repo left private. Pages won't be enabled — share the repo URL instead."
    echo "  Repo:  https://github.com/${GH_USER}/${REPO_NAME}"
    exit 0
  fi
fi

gh api -X POST "/repos/${GH_USER}/${REPO_NAME}/pages" \
  -f "source[branch]=main" \
  -f "source[path]=/" >/dev/null 2>&1 || \
gh api -X PUT "/repos/${GH_USER}/${REPO_NAME}/pages" \
  -f "source[branch]=main" \
  -f "source[path]=/" >/dev/null 2>&1 || true

URL="https://${GH_USER}.github.io/${REPO_NAME}/"

echo ""
echo "──────────────────────────────────────────────────────────────"
echo "  ✓ Deck deployed."
echo ""
echo "  Live URL:  ${URL}"
echo "  Repo:      https://github.com/${GH_USER}/${REPO_NAME}"
echo ""
echo "  GitHub Pages takes ~30–90 seconds to build the first time."
echo "──────────────────────────────────────────────────────────────"
