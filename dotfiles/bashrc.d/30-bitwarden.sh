# shellcheck shell=bash
# Bitwarden CLI helpers. Never put the master password, API client secret or a
# session key in a dotfile: `bw login` once (state is kept in
# ~/.config/Bitwarden CLI), then unlock per session.
#
#   bwu   unlock (prompts for the master password), export BW_SESSION and save it
#         to ~/.config/bw/session (mode 600) for scripts that read it from there
#   bwl   lock the vault and delete the saved session
export BW_SESSION_FILE="${BW_SESSION_FILE:-$HOME/.config/bw/session}"

# Pick up a session saved by an earlier bwu (only valid while the vault stays unlocked).
if [ -z "${BW_SESSION:-}" ] && [ -s "$BW_SESSION_FILE" ]; then
  BW_SESSION="$(cat "$BW_SESSION_FILE")"; export BW_SESSION
fi

bwu() {
  local s
  s="$(bw unlock --raw)" || return
  [ -n "$s" ] || { echo "bwu: unlock failed" >&2; return 1; }
  (umask 077; mkdir -p "$(dirname "$BW_SESSION_FILE")"; printf '%s' "$s" > "$BW_SESSION_FILE")
  export BW_SESSION="$s"
  echo "Vault unlocked (session saved to $BW_SESSION_FILE). Lock with: bwl"
}

bwl() {
  bw lock
  rm -f "$BW_SESSION_FILE"
  unset BW_SESSION
}
