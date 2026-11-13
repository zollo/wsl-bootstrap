#!/usr/bin/env bash
# Git defaults + identity from bootstrap.local.conf. Existing values are kept.
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"

set_default() {   # set_default <key> <value>: only if not already set
  if git config --global --get "$1" >/dev/null; then ok "git $1 = $(git config --global --get "$1") (kept)"
  else git config --global "$1" "$2"; ok "git $1 = $2"; fi
}

set_default init.defaultBranch main
set_default pull.rebase true
set_default fetch.prune true
set_default core.autocrlf input
[ -n "$GIT_NAME" ]  && set_default user.name "$GIT_NAME"
[ -n "$GIT_EMAIL" ] && set_default user.email "$GIT_EMAIL"
git config --global --get user.email >/dev/null || warn "git user.email not set (GIT_EMAIL in bootstrap.local.conf)"

# Let git use gh for HTTPS auth once gh is logged in.
if command -v gh >/dev/null && gh auth status >/dev/null 2>&1; then
  gh auth setup-git && ok "git HTTPS credentials via gh"
else
  warn "gh not logged in; run: gh auth login   (then re-run this step)"
fi
