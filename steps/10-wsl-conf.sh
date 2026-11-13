#!/usr/bin/env bash
# Install /etc/wsl.conf (systemd + default user) and keep systemd-binfmt from
# running under WSL. Backs up an existing wsl.conf that differs.
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"

if ! is_wsl; then warn "not running under WSL; skipping wsl.conf"; exit 0; fi

# systemd-binfmt shares binfmt_misc with every distro in the WSL VM: when it runs
# here, stopping this distro drops the WSLInterop entry and Windows binaries
# (wsl.exe, code, docker.exe) fail with "Exec format error" in all distros.
# Ubuntu 24.04's WSL image ships this guard; the 26.04 image doesn't.
dropin=/etc/systemd/system/systemd-binfmt.service.d/wsl-bootstrap.conf
dropin_want=$'# Installed by wsl-bootstrap: never run systemd-binfmt under WSL (it breaks interop).\n[Unit]\nConditionVirtualization=!wsl'
if [ "$(cat "$dropin" 2>/dev/null)" != "$dropin_want" ]; then
  sudo install -d -m 755 "$(dirname "$dropin")"
  printf '%s\n' "$dropin_want" | sudo tee "$dropin" >/dev/null
  sudo systemctl daemon-reload 2>/dev/null || true
  ok "systemd-binfmt disabled under WSL ($dropin)"
else
  ok "systemd-binfmt guard in place"
fi

want="$(sed "s/^default=__USER__$/default=$(id -un)/" "$REPO_DIR/config/wsl.conf")"
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
