#!/usr/bin/env bash
# apt: full upgrade, base packages, GitHub CLI from its own repo (the Ubuntu
# archive's gh lags far behind). Pass "optional" to install the optional list only.
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"

pkgs_from() { sed -e 's/#.*//' -e '/^\s*$/d' "$1"; }

if [ "${1:-}" = optional ]; then
  mapfile -t pkgs < <(pkgs_from "$REPO_DIR/config/apt-packages-optional.txt")
  info "apt: installing optional packages: ${pkgs[*]}"
  sudo apt-get install -y "${pkgs[@]}"
  exit 0
fi

export DEBIAN_FRONTEND=noninteractive
info "apt: update + upgrade"
sudo apt-get update -q
sudo -E apt-get -y -q full-upgrade

mapfile -t pkgs < <(pkgs_from "$REPO_DIR/config/apt-packages.txt")
info "apt: installing ${#pkgs[@]} base packages"
sudo -E apt-get install -y -q "${pkgs[@]}"

# GitHub CLI apt repo (https://github.com/cli/cli/blob/trunk/docs/install_linux.md)
keyring=/etc/apt/keyrings/githubcli-archive-keyring.gpg
list=/etc/apt/sources.list.d/github-cli.list
if [ ! -s "$keyring" ] || [ ! -f "$list" ]; then
  info "apt: adding GitHub CLI repository"
  sudo install -d -m 755 /etc/apt/keyrings
  curl -fsSL https://cli.github.com/packages/githubcli-archive-keyring.gpg | sudo tee "$keyring" >/dev/null
  sudo chmod go+r "$keyring"
  echo "deb [arch=$ARCH signed-by=$keyring] https://cli.github.com/packages stable main" | sudo tee "$list" >/dev/null
  sudo apt-get update -q
fi
sudo -E apt-get install -y -q gh

sudo apt-get autoremove -y -q
ok "apt done"
