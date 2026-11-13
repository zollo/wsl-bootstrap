#!/usr/bin/env bash
# Pinned CLI tools into ~/.local/bin (no root needed to update them later).
# Versions/hashes: versions.env. Already-current tools are skipped; FORCE=1 reinstalls.
# Pass tool names to install a subset: steps/30-tools.sh kubectl helm
set -euo pipefail
. "$(dirname "$0")/../lib/common.sh"

for c in curl unzip tar sha256sum; do
  command -v "$c" >/dev/null || die "$c not found; run './bootstrap.sh apt' first"
done
mkdir -p "$BIN_DIR"
make_tmp

case "$ARCH" in
  amd64) ;; arm64) ;; *) die "unsupported architecture: $ARCH" ;;
esac

install_kubectl() {
  up_to_date kubectl "v$KUBECTL_VERSION" "$BIN_DIR/kubectl" version --client && return
  local base="https://dl.k8s.io/release/v$KUBECTL_VERSION/bin/linux/$ARCH"
  download "$base/kubectl" "$TMP/kubectl"
  download "$base/kubectl.sha256" "$TMP/kubectl.sha256"
  verify_sha256 "$TMP/kubectl" "$(tr -d '[:space:]' < "$TMP/kubectl.sha256")"
  install -m 755 "$TMP/kubectl" "$BIN_DIR/kubectl"
  ok "kubectl $KUBECTL_VERSION"
}

install_helm() {
  up_to_date helm "v$HELM_VERSION" "$BIN_DIR/helm" version --short && return
  local f="helm-v$HELM_VERSION-linux-$ARCH.tar.gz"
  download "https://get.helm.sh/$f" "$TMP/$f"
  download "https://get.helm.sh/$f.sha256sum" "$TMP/$f.sha256sum"
  verify_sha256 "$TMP/$f" "$(awk '{print $1}' "$TMP/$f.sha256sum")"
  tar -xzf "$TMP/$f" -C "$TMP"
  install -m 755 "$TMP/linux-$ARCH/helm" "$BIN_DIR/helm"
  ok "helm $HELM_VERSION"
}

install_tofu() {
  up_to_date tofu "v$TOFU_VERSION" "$BIN_DIR/tofu" version && return
  local f="tofu_${TOFU_VERSION}_linux_$ARCH.zip"
  local base="https://github.com/opentofu/opentofu/releases/download/v$TOFU_VERSION"
  download "$base/$f" "$TMP/$f"
  download "$base/tofu_${TOFU_VERSION}_SHA256SUMS" "$TMP/tofu.sums"
  verify_sha256 "$TMP/$f" "$(sha_from_sums "$TMP/tofu.sums" "$f")"
  unzip -oq "$TMP/$f" tofu -d "$TMP"
  install -m 755 "$TMP/tofu" "$BIN_DIR/tofu"
  ok "tofu $TOFU_VERSION"
}

install_packer() {
  up_to_date packer "v$PACKER_VERSION" "$BIN_DIR/packer" version && return
  local f="packer_${PACKER_VERSION}_linux_$ARCH.zip"
  local base="https://releases.hashicorp.com/packer/$PACKER_VERSION"
  download "$base/$f" "$TMP/$f"
  download "$base/packer_${PACKER_VERSION}_SHA256SUMS" "$TMP/packer.sums"
  verify_sha256 "$TMP/$f" "$(sha_from_sums "$TMP/packer.sums" "$f")"
  unzip -oq "$TMP/$f" packer -d "$TMP"
  install -m 755 "$TMP/packer" "$BIN_DIR/packer"
  ok "packer $PACKER_VERSION"
}

install_bw() {
  up_to_date bw "$BW_VERSION" "$BIN_DIR/bw" --version && return
  local f sha
  if [ "$ARCH" = amd64 ]; then f="bw-linux-$BW_VERSION.zip"; sha="$BW_SHA256_AMD64"
  else f="bw-linux-arm64-$BW_VERSION.zip"; sha="$BW_SHA256_ARM64"; fi
  [ -n "$sha" ] || die "no pinned hash for $f in versions.env"
  download "https://github.com/bitwarden/clients/releases/download/cli-v$BW_VERSION/$f" "$TMP/$f"
  verify_sha256 "$TMP/$f" "$sha"
  unzip -oq "$TMP/$f" bw -d "$TMP"
  install -m 755 "$TMP/bw" "$BIN_DIR/bw"
  ok "bw $BW_VERSION"
}

install_bws() {
  up_to_date bws "$BWS_VERSION" "$BIN_DIR/bws" --version && return
  local triple; [ "$ARCH" = amd64 ] && triple=x86_64-unknown-linux-gnu || triple=aarch64-unknown-linux-gnu
  local f="bws-$triple-$BWS_VERSION.zip"
  local base="https://github.com/bitwarden/sdk-sm/releases/download/bws-v$BWS_VERSION"
  download "$base/$f" "$TMP/$f"
  download "$base/bws-sha256-checksums-$BWS_VERSION.txt" "$TMP/bws.sums"
  verify_sha256 "$TMP/$f" "$(sha_from_sums "$TMP/bws.sums" "$f")"
  unzip -oq "$TMP/$f" bws -d "$TMP"
  install -m 755 "$TMP/bws" "$BIN_DIR/bws"
  ok "bws $BWS_VERSION"
}

install_yq() {
  up_to_date yq "v$YQ_VERSION" "$BIN_DIR/yq" --version && return
  local sha; [ "$ARCH" = amd64 ] && sha="$YQ_SHA256_AMD64" || sha="$YQ_SHA256_ARM64"
  download "https://github.com/mikefarah/yq/releases/download/v$YQ_VERSION/yq_linux_$ARCH" "$TMP/yq"
  verify_sha256 "$TMP/yq" "$sha"
  install -m 755 "$TMP/yq" "$BIN_DIR/yq"
  ok "yq $YQ_VERSION"
}

ALL=(kubectl helm tofu packer bw bws yq)
tools=("$@"); [ ${#tools[@]} -gt 0 ] || tools=("${ALL[@]}")
for t in "${tools[@]}"; do
  declare -F "install_$t" >/dev/null || die "unknown tool: $t (known: ${ALL[*]})"
  info "tool: $t"
  "install_$t"
done
