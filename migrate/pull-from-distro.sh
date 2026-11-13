#!/usr/bin/env bash
# Run INSIDE the new distro: copy $HOME paths from another WSL distro into this
# one, streamed through `wsl.exe -d <source> -- tar` (nothing is written to the
# Windows drive). Owner/permissions are preserved.
#
#   migrate/pull-from-distro.sh <source-distro> [--dry-run] [--overwrite] [path...]
#
# Without paths: migrate/paths.txt + migrate/paths.local.txt. Excludes:
# migrate/excludes.txt + migrate/excludes.local.txt.
# Existing files here are kept unless --overwrite.
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"

usage() { sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'; exit "${1:-0}"; }
[ $# -ge 1 ] || usage 1
case "$1" in -h|--help) usage ;; esac
src="$1"; shift
dry=0; overwrite=0; paths=()
for a in "$@"; do
  case "$a" in
    --dry-run) dry=1 ;; --overwrite) overwrite=1 ;; -*) usage 1 ;; *) paths+=("$a") ;;
  esac
done

is_wsl || die "must run inside WSL"
[ "$src" != "${WSL_DISTRO_NAME:-}" ] || die "source and target are the same distro"

readlist() { [ -f "$1" ] && sed -e 's/#.*//' -e 's/[[:space:]]*$//' -e '/^$/d' "$1"; return 0; }
if [ ${#paths[@]} -eq 0 ]; then
  mapfile -t paths < <(readlist "$REPO_DIR/migrate/paths.txt"; readlist "$REPO_DIR/migrate/paths.local.txt")
fi
mapfile -t excludes < <(readlist "$REPO_DIR/migrate/excludes.txt"; readlist "$REPO_DIR/migrate/excludes.local.txt")

# wsl.exe needs a Windows-reachable cwd, or it warns about path translation.
# wsl.exe reads stdin even when the command does not: callers redirect it.
wslx() { (cd /mnt/c && wsl.exe -d "$src" --cd "~" -- "$@"); }

wslx true </dev/null || die "can't start distro '$src' (wsl.exe -l -v to list)"

# Keep only paths that exist in the source.
existing=()
for p in "${paths[@]}"; do
  if wslx test -e "$p" </dev/null; then existing+=("$p"); else warn "not in $src: ~/$p"; fi
done
[ ${#existing[@]} -gt 0 ] || die "nothing to copy"

info "from $src:~ to $(hostname)/${WSL_DISTRO_NAME:-?}:~"
wslx du -sh "${existing[@]}" </dev/null | sed 's/^/    /'
[ "$dry" = 1 ] && { ok "dry run, nothing copied"; exit 0; }

ex=(); for e in "${excludes[@]}"; do ex+=("--exclude=$e"); done
keep=(--skip-old-files)
if [ "$overwrite" = 1 ]; then
  keep=(--overwrite)
  # --overwrite can't open read-only files (git objects); tar -p restores the modes after.
  for p in "${existing[@]}"; do [ -e "$HOME/$p" ] && chmod -R u+w "$HOME/$p"; done
fi

wslx tar -cf - "${ex[@]}" -- "${existing[@]}" </dev/null \
  | tar -C "$HOME" -xpf - "${keep[@]}"

# Lock down what's sensitive regardless of source perms.
[ -d "$HOME/.ssh" ] && { chmod 700 "$HOME/.ssh"; find "$HOME/.ssh" -type f ! -name '*.pub' ! -name known_hosts\* -exec chmod 600 {} +; }
[ -d "$HOME/.kube" ] && chmod -R go-rwx "$HOME/.kube"
ok "copied ${#existing[@]} paths"
