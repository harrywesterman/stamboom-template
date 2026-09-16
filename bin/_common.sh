#!/usr/bin/env bash
# Interne helper: paden, env-bestanden en logfuncties voor de overige scripts.
# Wordt gesourced, niet uitgevoerd.

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SECRETS="${STAMBOOM_SECRETS:-$HOME/.config/stamboom/secrets.env}"
PROJECT_ENV="$ROOT/config/project.env"

_load_env() {
    [ -f "$1" ] || return 0
    set -a
    # shellcheck disable=SC1090
    . "$1"
    set +a
}
_load_env "$SECRETS"
_load_env "$PROJECT_ENV"

TOOLS_DIR="${TOOLS_DIR:-$HOME/.local/share/stamboom-tools}"
OCR_MODELS="${OCR_MODELS:-$HOME/ocr-models}"
KRAKEN_VENV="${KRAKEN_VENV:-$OCR_MODELS/.venv-kraken}"

if [ -t 1 ]; then
    C_RESET=$'\033[0m'; C_BOLD=$'\033[1m'
    C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'; C_RED=$'\033[31m'
else
    C_RESET=''; C_BOLD=''; C_GREEN=''; C_YELLOW=''; C_RED=''
fi

log()  { printf '\n%s== %s%s\n' "$C_BOLD" "$*" "$C_RESET"; }
ok()   { printf '  %sok%s    %s\n' "$C_GREEN" "$C_RESET" "$*"; }
skip() { printf '  %sskip%s  %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
warn() { printf '  %swarn%s  %s\n' "$C_YELLOW" "$C_RESET" "$*"; }
err()  { printf '  %sfout%s  %s\n' "$C_RED" "$C_RESET" "$*" >&2; }
die()  { err "$*"; exit 1; }

need() {
    command -v "$1" >/dev/null 2>&1 || die "vereist commando '$1' niet gevonden (installeer het en probeer opnieuw)"
}
