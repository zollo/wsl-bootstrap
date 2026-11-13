# Shared helpers for bootstrap steps. Sourced, not executed.
# shellcheck shell=bash disable=SC2034  # variables are used by the sourcing steps

REPO_DIR="${REPO_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"

if [ -t 1 ]; then
  _c_info=$'\e[1;34m'; _c_ok=$'\e[1;32m'; _c_warn=$'\e[1;33m'; _c_err=$'\e[1;31m'; _c_off=$'\e[0m'
else
  _c_info=; _c_ok=; _c_warn=; _c_err=; _c_off=
fi
info() { printf '%s==>%s %s\n' "$_c_info" "$_c_off" "$*"; }
ok()   { printf '%s ok%s %s\n' "$_c_ok" "$_c_off" "$*"; }
warn() { printf '%swarn%s %s\n' "$_c_warn" "$_c_off" "$*" >&2; }
die()  { printf '%serror%s %s\n' "$_c_err" "$_c_off" "$*" >&2; exit 1; }

is_wsl() { grep -qi microsoft /proc/sys/kernel/osrelease 2>/dev/null; }

# Defaults; override in bootstrap.local.conf (see bootstrap.local.conf.example).
GIT_NAME="${GIT_NAME:-}"
GIT_EMAIL="${GIT_EMAIL:-}"
WINDOWS_LINKS=()
OPTIONAL_APT="${OPTIONAL_APT:-0}"
SKIP_CLAUDE="${SKIP_CLAUDE:-0}"

# Load pinned versions, then optional local overrides (gitignored).
# shellcheck source=../versions.env
. "$REPO_DIR/versions.env"
# shellcheck disable=SC1091
[ -f "$REPO_DIR/bootstrap.local.conf" ] && . "$REPO_DIR/bootstrap.local.conf"

ARCH="$(dpkg --print-architecture)"   # amd64 / arm64

# Temporary download dir, removed on exit.
make_tmp() {
  TMP="$(mktemp -d)"
  # shellcheck disable=SC2064
  trap "rm -rf '$TMP'" EXIT
}

# download <url> <dest>
download() { curl -fsSL --retry 3 -o "$2" "$1"; }

# verify_sha256 <file> <expected-hex>
verify_sha256() {
  local got
  got="$(sha256sum "$1" | awk '{print $1}')"
  [ "$got" = "$2" ] || die "checksum mismatch for $(basename "$1"): expected $2, got $got"
}

# sha_from_sums <sums-file> <filename>: print the hash for filename from a SHA256SUMS-style file
sha_from_sums() {
  awk -v f="$2" '$2 == f || $2 == "*"f {print $1; exit}' "$1"
}

# up_to_date <name> <version> <command...>: true if the command's output mentions the version
# (skip reinstalling) unless FORCE=1.
up_to_date() {
  local name="$1" ver="$2"; shift 2
  [ "${FORCE:-0}" = 1 ] && return 1
  if "$@" 2>/dev/null | head -3 | grep -qF "$ver"; then
    ok "$name $ver already installed"
    return 0
  fi
  return 1
}
