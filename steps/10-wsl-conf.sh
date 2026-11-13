#!/usr/bin/env bash
# Install /etc/wsl.conf (systemd + default user) and a timer that restores WSL
# interop if another distro drops it. Backs up an existing wsl.conf that differs.
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"

if ! is_wsl; then warn "not running under WSL; skipping wsl.conf"; exit 0; fi

# binfmt_misc is shared by every distro in the WSL VM, and stopping another
# distro can drop the WSLInterop entry: Windows binaries (wsl.exe, code,
# docker.exe) then fail with "Exec format error" here. A root timer puts it back.
heal_changed=0
install_if_changed() {   # install_if_changed <src> <dest> <mode>
  if ! cmp -s "$1" "$2"; then sudo install -m "$3" "$1" "$2"; heal_changed=1; fi
}
install_if_changed "$REPO_DIR/config/wsl-interop-heal.sh" /usr/local/sbin/wsl-interop-heal 755
install_if_changed "$REPO_DIR/config/wsl-interop-heal.service" /etc/systemd/system/wsl-interop-heal.service 644
install_if_changed "$REPO_DIR/config/wsl-interop-heal.timer" /etc/systemd/system/wsl-interop-heal.timer 644
# Earlier versions disabled systemd-binfmt instead; that also stops WSL's own
# boot-time re-registration, so remove it.
old=/etc/systemd/system/systemd-binfmt.service.d/wsl-bootstrap.conf
if [ -e "$old" ]; then sudo rm -f "$old"; sudo rmdir --ignore-fail-on-non-empty "$(dirname "$old")"; heal_changed=1; fi
if [ "$(ps -p 1 -o comm=)" = systemd ]; then
  [ "$heal_changed" = 1 ] && sudo systemctl daemon-reload
  sudo systemctl enable --now wsl-interop-heal.timer >/dev/null 2>&1
  ok "wsl-interop-heal.timer active"
else
  sudo install -d /etc/systemd/system/timers.target.wants
  sudo ln -sf /etc/systemd/system/wsl-interop-heal.timer /etc/systemd/system/timers.target.wants/
  ok "wsl-interop-heal.timer enabled (starts once systemd runs)"
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
