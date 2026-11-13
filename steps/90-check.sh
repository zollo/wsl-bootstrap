#!/usr/bin/env bash
# Report what's installed and what still needs a manual step. Changes nothing.
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"
export PATH="$BIN_DIR:$PATH"

row() { printf '  %-10s %s\n' "$1" "$2"; }
ver() { command -v "$1" >/dev/null || { echo "MISSING"; return; }; "$@" 2>/dev/null | head -1; }

echo "System"
row os "$(. /etc/os-release; echo "$PRETTY_NAME")"
row kernel "$(uname -r)"
row systemd "$( [ "$(ps -p 1 -o comm=)" = systemd ] && echo running || echo 'NOT pid 1 (restart distro after wsl.conf)')"
echo "Tools"
row kubectl "$(ver kubectl version --client | sed 's/Client Version: //')"
row helm    "$(ver helm version --short)"
row tofu    "$(ver tofu version)"
row packer  "$(ver packer version)"
row bw      "$(ver bw --version)"
row bws     "$(ver bws --version)"
row yq      "$(ver yq --version)"
row jq      "$(ver jq --version)"
row gh      "$(ver gh --version)"
row xorriso "$(ver xorriso -version)"
row claude  "$(ver claude --version)"
echo "Integration"
if command -v docker >/dev/null && docker version --format '{{.Server.Version}}' >/dev/null 2>&1; then
  row docker "server $(docker version --format '{{.Server.Version}}') via $(command -v docker)"
else
  row docker "not reachable: Docker Desktop > Settings > Resources > WSL integration > enable this distro"
fi
row gh-auth "$(gh auth status >/dev/null 2>&1 && echo 'logged in' || echo 'run: gh auth login')"
row bw-auth "$(bw status 2>/dev/null | jq -r .status 2>/dev/null || echo unknown) (unauthenticated -> bw login; locked -> bwu)"
keys=(); for k in "$HOME"/.ssh/id_*; do [ -f "$k" ] && [ "${k%.pub}" = "$k" ] && keys+=("$(basename "$k")"); done
row ssh-keys "${keys[*]:-none in ~/.ssh}"
