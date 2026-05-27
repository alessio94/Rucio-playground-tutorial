#!/bin/bash
# Generate a self-signed TLS certificate for the RustFS container.
# Outputs: etc/certs/rustfs/public.crt and etc/certs/rustfs/private.key
# Called by qt-000-up.sh from the repo root.

set -euo pipefail

CERT_DIR="$(dirname "$0")/rustfs"
mkdir -p "$CERT_DIR"

openssl req -x509 -nodes -days 3650 \
  -newkey rsa:2048 \
  -keyout "$CERT_DIR/private.key" \
  -out "$CERT_DIR/public.crt" \
  -subj "/CN=rustfs" \
  -addext "subjectAltName=DNS:rustfs,DNS:localhost,IP:127.0.0.1" \
  2>/dev/null

chmod 644 "$CERT_DIR/public.crt" "$CERT_DIR/private.key"
echo "RustFS TLS cert written to $CERT_DIR/"
