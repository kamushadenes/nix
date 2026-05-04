#!/usr/bin/env bash
# Rotate STREMTHRU_PROXY_AUTH token: regenerate, re-encrypt agenix file,
# remind operator to redeploy + reconfigure AIOStreams.
set -euo pipefail

REPO_ROOT="$(git -C "$(dirname "$0")" rev-parse --show-toplevel)"
SECRETS_DIR="${REPO_ROOT}/private/nixos/secrets/stremthru"
ENV_FILE="${SECRETS_DIR}/stremthru-env.age"

[ -f "$ENV_FILE" ] || { echo "FAIL: $ENV_FILE not found"; exit 1; }

NEW_TOKEN="$(openssl rand -base64 32 | tr -d '=+/' | head -c 32)"

# Read existing decrypted env (preserves any non-rotated values), substitute
# the auth, then re-encrypt under the same recipients defined in secrets.nix.
TMP="$(mktemp)"
trap 'rm -f "$TMP"' EXIT
agenix -d "$ENV_FILE" -i ~/.age/age.pem | \
  sed -E "s|^STREMTHRU_PROXY_AUTH=.*|STREMTHRU_PROXY_AUTH=admin:${NEW_TOKEN}|" > "$TMP"

EDITOR="cp -f $TMP" agenix -e "$ENV_FILE" -i ~/.age/age.pem

cat <<EOF
StremThru proxy auth rotated.
  New value: admin:${NEW_TOKEN}

Next steps:
  1. Commit private submodule + main repo
  2. Deploy:  rebuild -vL stremthru   (or via aether)
  3. AIOStreams: update StremThru endpoint URL with new auth in
     https://aiostreams.hyades.io/stremio/configure
EOF
