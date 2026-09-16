#!/usr/bin/env bash
# Healthcheck van alle MCP-servers en lokale voorzieningen.
#
#   ./bin/doctor.sh [--verbose]

set -euo pipefail
exec node "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/doctor.mjs" "$@"
