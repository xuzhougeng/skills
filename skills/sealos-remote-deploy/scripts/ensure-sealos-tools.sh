#!/usr/bin/env bash
set -euo pipefail

SEALOS_VERSION="${SEALOS_VERSION:-5.1.1}"
BIN_DIR="${BIN_DIR:-$HOME/.local/bin}"
KUBECTL_VERSION="${KUBECTL_VERSION:-}"

mkdir -p "$BIN_DIR"

need_sealos=0
if ! command -v sealos >/dev/null 2>&1; then
  need_sealos=1
elif ! sealos version 2>/dev/null | grep -q "gitVersion: ${SEALOS_VERSION}"; then
  need_sealos=1
fi

if [ "$need_sealos" -eq 1 ]; then
  tmpdir="$(mktemp -d)"
  trap 'rm -rf "$tmpdir"' EXIT
  archive="$tmpdir/sealos_${SEALOS_VERSION}_linux_amd64.tar.gz"
  wget -O "$archive" "https://github.com/labring/sealos/releases/download/v${SEALOS_VERSION}/sealos_${SEALOS_VERSION}_linux_amd64.tar.gz"
  tar xf "$archive" -C "$tmpdir"
  mv "$tmpdir/sealos" "$BIN_DIR/sealos"
  chmod +x "$BIN_DIR/sealos"
fi

if ! command -v kubectl >/dev/null 2>&1 && [ ! -x "$BIN_DIR/kubectl" ]; then
  if [ -z "$KUBECTL_VERSION" ]; then
    KUBECTL_VERSION="$(curl -L -s https://dl.k8s.io/release/stable.txt)"
  fi
  curl -L -o "$BIN_DIR/kubectl" "https://dl.k8s.io/release/${KUBECTL_VERSION}/bin/linux/amd64/kubectl"
  chmod +x "$BIN_DIR/kubectl"
fi

export PATH="$BIN_DIR:$PATH"
sealos version
"${BIN_DIR}/kubectl" version --client 2>/dev/null || kubectl version --client
