#!/usr/bin/env bash
# Generate POSTGRES_PASSWORD + ZILEAN_DB_CONN env file content for
# postgres-zilean.age. Pipe stdout into agenix:
#   ./gen-postgres-zilean.sh | EDITOR=tee agenix -e postgres-zilean.age
set -euo pipefail
PASS="$(openssl rand -base64 32 | tr -d '=+/' | head -c 32)"
cat <<EOF
POSTGRES_PASSWORD=${PASS}
ZILEAN_DB_CONN=Host=zilean-postgres;Database=zilean;Username=zilean;Password=${PASS}
EOF
