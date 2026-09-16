#!/usr/bin/env bash
# Maakt ~/.config/stamboom/secrets.env aan (chmod 600, buiten de repo) en opent het.
#
#   ./bin/secrets-edit.sh

set -euo pipefail
# shellcheck source=bin/_common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

mkdir -p "$(dirname "$SECRETS")"

if [ ! -f "$SECRETS" ]; then
    cp "$ROOT/config/secrets.env.example" "$SECRETS"
    ok "aangemaakt: $SECRETS"
else
    ok "bestaat al: $SECRETS"
fi

chmod 600 "$SECRETS"

if [ ! -t 0 ] || [ ! -t 1 ]; then
    printf 'Niet-interactief: vul %s handmatig in.\n' "$SECRETS"
    exit 0
fi

"${EDITOR:-${VISUAL:-vi}}" "$SECRETS"
printf '\nOpgeslagen. Controleer met: ./setup.sh --check\n'
