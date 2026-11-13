# shellcheck shell=bash
# ~/.local/bin first (pinned tools, Claude Code).
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *) PATH="$HOME/.local/bin:$PATH" ;; esac
export PATH
export EDITOR="${EDITOR:-nano}"
