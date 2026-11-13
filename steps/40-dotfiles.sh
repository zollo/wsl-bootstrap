#!/usr/bin/env bash
# Shell config: copy dotfiles/bashrc.d/*.sh to ~/.bashrc.d/ and source that
# directory from ~/.bashrc (one marked block, added once). Symlink Windows-side
# config dirs (WINDOWS_LINKS in bootstrap.local.conf) into $HOME.
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"

dest="$HOME/.bashrc.d"
mkdir -p "$dest"
for f in "$REPO_DIR"/dotfiles/bashrc.d/*.sh; do
  install -m 644 "$f" "$dest/$(basename "$f")"
done
ok "installed $(find "$REPO_DIR/dotfiles/bashrc.d" -name '*.sh' | wc -l) snippets to $dest (add your own as *.local.sh; those are left alone)"

marker="# >>> wsl-bootstrap >>>"
if ! grep -qF "$marker" "$HOME/.bashrc" 2>/dev/null; then
  cp -a "$HOME/.bashrc" "$HOME/.bashrc.bak.$(date +%Y%m%d-%H%M%S)" 2>/dev/null || true
  cat >> "$HOME/.bashrc" <<'EOF'

# >>> wsl-bootstrap >>>
for __f in "$HOME"/.bashrc.d/*.sh; do [ -r "$__f" ] && . "$__f"; done
unset __f
# <<< wsl-bootstrap <<<
EOF
  ok "$HOME/.bashrc now sources $HOME/.bashrc.d"
else
  ok "$HOME/.bashrc already sources $HOME/.bashrc.d"
fi

# Windows-side links (e.g. ~/.aws -> /mnt/c/Users/<you>/.aws)
if is_wsl && [ "${#WINDOWS_LINKS[@]}" -gt 0 ]; then
  winprofile="$(cd /mnt/c 2>/dev/null && cmd.exe /c 'echo %USERPROFILE%' 2>/dev/null | tr -d '\r')" || winprofile=
  if [ -n "$winprofile" ]; then
    winhome="$(wslpath -u "$winprofile")"
    for pair in "${WINDOWS_LINKS[@]}"; do
      name="${pair%%:*}"; target="$winhome/${pair#*:}"
      if [ ! -e "$target" ]; then warn "skip ~/$name: $target does not exist"; continue; fi
      if [ -L "$HOME/$name" ]; then ok "$HOME/$name already linked"; continue; fi
      if [ -e "$HOME/$name" ]; then warn "skip ~/$name: exists and is not a symlink"; continue; fi
      ln -s "$target" "$HOME/$name"
      ok "$HOME/$name -> $target"
    done
  else
    warn "couldn't read %USERPROFILE% (Windows interop off?); skipping Windows links"
  fi
fi
