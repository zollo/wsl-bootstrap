#!/usr/bin/env bash
# Install /etc/wsl.conf (systemd + default user). Backs up an existing file that differs.
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"

if ! is_wsl; then warn "not running under WSL; skipping wsl.conf"; exit 0; fi

want="$(sed "s/__USER__/$(id -un)/" "$REPO_DIR/config/wsl.conf")"
if [ -f /etc/wsl.conf ] && [ "$(cat /etc/wsl.conf)" = "$want" ]; then
  ok "/etc/wsl.conf up to date"
  exit 0
fi

if [ -f /etc/wsl.conf ]; then
  bak="/etc/wsl.conf.bak.$(date +%Y%m%d-%H%M%S)"
  sudo cp -a /etc/wsl.conf "$bak"
  info "backed up existing /etc/wsl.conf to $bak"
fi
printf '%s\n' "$want" | sudo tee /etc/wsl.conf >/dev/null
ok "/etc/wsl.conf written; restart the distro to apply (wsl.exe --terminate \$WSL_DISTRO_NAME)"
