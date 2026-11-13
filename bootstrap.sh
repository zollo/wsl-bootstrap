#!/usr/bin/env bash
# Bootstrap an Ubuntu WSL2 distro. Idempotent: safe to re-run any time.
#
#   ./bootstrap.sh                 all steps
#   ./bootstrap.sh tools check     only those steps
#   FORCE=1 ./bootstrap.sh tools   reinstall pinned tools even if current
#
# Steps: wsl-conf apt apt-optional tools dotfiles git claude check
set -euo pipefail
REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
export REPO_DIR
. "$REPO_DIR/lib/common.sh"

[ "$(id -u)" -ne 0 ] || die "run as your normal user (sudo is used where needed), not root"

declare -A STEP=(
  [wsl-conf]=10-wsl-conf.sh [apt]=20-apt.sh [tools]=30-tools.sh [dotfiles]=40-dotfiles.sh
  [git]=50-git.sh [claude]=60-claude.sh [check]=90-check.sh
)
ORDER=(wsl-conf apt tools dotfiles git claude check)

usage() { sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
case "${1:-}" in -h|--help) usage ;; esac

steps=("$@")
if [ ${#steps[@]} -eq 0 ]; then
  steps=("${ORDER[@]}")
  [ "$OPTIONAL_APT" = 1 ] && steps=(wsl-conf apt apt-optional tools dotfiles git claude check)
fi
for s in "${steps[@]}"; do
  [ "$s" = apt-optional ] || [ -n "${STEP[$s]:-}" ] || { warn "unknown step: $s"; usage 1; }
done

# Ask for sudo once and keep it alive while we run.
if printf '%s\n' "${steps[@]}" | grep -qxE 'wsl-conf|apt|apt-optional'; then
  sudo -n true 2>/dev/null || sudo -v
  while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done 2>/dev/null &
fi

for s in "${steps[@]}"; do
  echo
  info "step: $s"
  if [ "$s" = apt-optional ]; then "$REPO_DIR/steps/20-apt.sh" optional
  else "$REPO_DIR/steps/${STEP[$s]}"; fi
done

echo
ok "bootstrap finished. Open a new shell (or: exec bash) to pick up the shell config."
