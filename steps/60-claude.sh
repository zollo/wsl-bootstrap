#!/usr/bin/env bash
# Claude Code via the official native installer (self-updates afterwards).
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"

[ "$SKIP_CLAUDE" = 1 ] && { ok "Claude Code skipped (SKIP_CLAUDE=1)"; exit 0; }
if [ -x "$BIN_DIR/claude" ] && [ "${FORCE:-0}" != 1 ]; then
  ok "Claude Code already installed: $("$BIN_DIR/claude" --version 2>/dev/null)"
  exit 0
fi
make_tmp
download https://claude.ai/install.sh "$TMP/install.sh"
bash "$TMP/install.sh"
ok "Claude Code installed; run 'claude' to log in"
