#!/usr/bin/env bash
# Vult de projectgegevens in: boom, webtrees-URL en root-persoon.
#
#   ./bin/init-project.sh
#
# Niet-interactief (bv. in een script):
#   WEBTREES_TREE=tree1 WEBTREES_URL=https://… ROOT_XREF=I1 ROOT_NAME='Jan Jansen' ./bin/init-project.sh
#
# Vervangt de {{placeholders}} in AGENTS.md en docs/onderzoek/_TEMPLATE.md en schrijft
# config/project.env. Waarden uit secrets.env/project.env worden als default gebruikt,
# dus opnieuw draaien is veilig.

set -euo pipefail
# shellcheck source=bin/_common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

# Zonder terminal niet aan prompts beginnen: dan wacht `read` voor altijd.
INTERACTIVE=0
[ -t 0 ] && INTERACTIVE=1

# `${!var+x}` onderscheidt "expliciet leeg" van "niet gezet"; een lege waarde uit
# project.env telt dus als ingevuld en levert geen prompt op.
_is_set() { [ "${!1+x}" = "x" ]; }

_ask() { # _ask <varname> <prompt> <default> <verplicht:0|1>
    local __var="$1" __prompt="$2" __default="${3:-}" __required="$4" __input=""

    if _is_set "$__var" && [ "$__required" = "0" ]; then
        ok "$__var = ${!__var:-<leeg>}"
        return 0
    fi
    if _is_set "$__var" && [ -n "${!__var}" ]; then
        ok "$__var = ${!__var}"
        return 0
    fi

    if [ "$INTERACTIVE" = "0" ]; then
        printf -v "$__var" '%s' "${!__var:-$__default}"
        if [ -n "${!__var}" ]; then
            ok "$__var = ${!__var}"
        elif [ "$__required" = "1" ]; then
            die "$__var is niet gezet (niet-interactief)"
        else
            ok "$__var = <leeg>"
        fi
        return 0
    fi

    if [ -n "$__default" ]; then
        read -r -p "$__prompt [$__default]: " __input || true
        __input="${__input:-$__default}"
    else
        while :; do
            read -r -p "$__prompt: " __input || true
            [ -n "$__input" ] || [ "$__required" = "0" ] && break
        done
    fi
    printf -v "$__var" '%s' "$__input"
}

ask()     { _ask "$1" "$2" "${3:-}" 1; }
ask_opt() { _ask "$1" "$2" "${3:-}" 0; }

log "projectgegevens"
ask WEBTREES_TREE "webtrees-boomnaam (bestandsnaam)" "tree1"
ask WEBTREES_URL  "webtrees-URL" "https://www.stamboomwesterman.net"
ask_opt ROOT_NAME "root-persoon naam" ""
ask_opt ROOT_XREF "root-persoon XREF (bv. I1 — leeg als nog niet bekend)" ""

# %q zodat waarden met spaties/aanhalingstekens veilig te sourcen zijn:
# dit bestand wordt door bin/_common.sh met `.` ingelezen.
{
    printf '# Projectgegevens — automatisch geschreven door bin/init-project.sh.\n'
    printf 'WEBTREES_TREE=%q\n' "$WEBTREES_TREE"
    printf 'WEBTREES_URL=%q\n' "$WEBTREES_URL"
    printf 'ROOT_XREF=%q\n' "$ROOT_XREF"
    printf 'ROOT_NAME=%q\n' "$ROOT_NAME"
} > "$ROOT/config/project.env"
ok "geschreven: config/project.env"

STB_TREE="$WEBTREES_TREE" STB_URL="$WEBTREES_URL" STB_XREF="$ROOT_XREF" STB_NAME="$ROOT_NAME" \
node -e '
const fs = require("fs");
const name = process.env.STB_NAME || "(nog niet bepaald)";
const xref = process.env.STB_XREF;
const map = {
  // Eerst het samengestelde patroon, zodat een lege XREF geen "()" achterlaat.
  "{{ROOT_NAME}} ({{ROOT_XREF}})": xref ? `${name} (${xref})` : name,
  "{{ROOT_NAME}}": name,
  "{{ROOT_XREF}}": xref || "(nog niet bekend)",
  "{{TREE}}": process.env.STB_TREE,
  "{{WEBTREES_URL}}": process.env.STB_URL,
};
for (const file of process.argv.slice(1)) {
  if (!fs.existsSync(file)) continue;
  const before = fs.readFileSync(file, "utf8");
  let after = before;
  for (const [k, v] of Object.entries(map)) after = after.split(k).join(v);
  if (after !== before) {
    fs.writeFileSync(file, after);
    console.log("ingevuld:", file);
  }
}
' "$ROOT/AGENTS.md" "$ROOT/docs/onderzoek/_TEMPLATE.md"

if grep -q '{{' "$ROOT/AGENTS.md"; then
    warn "AGENTS.md bevat nog placeholders — controleer handmatig"
else
    ok "AGENTS.md ingevuld"
fi

log "klaar"
printf 'Render de configuratie opnieuw met: ./setup.sh --check\n'
