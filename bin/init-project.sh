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

ask() { # ask <varname> <prompt> <default>
    local __var="$1" __prompt="$2" __default="${3:-}" __input=""
    if [ -n "${!__var:-}" ]; then
        ok "$__var = ${!__var} (overgenomen)"
        return 0
    fi
    if [ -n "$__default" ]; then
        read -r -p "$__prompt [$__default]: " __input || true
        __input="${__input:-$__default}"
    else
        while [ -z "$__input" ]; do
            read -r -p "$__prompt: " __input || true
        done
    fi
    printf -v "$__var" '%s' "$__input"
}

log "projectgegevens"
ask WEBTREES_TREE "webtrees-boomnaam (bestandsnaam)" "tree1"
ask WEBTREES_URL  "webtrees-URL" "https://www.stamboomwesterman.net"
ask ROOT_XREF     "root-persoon XREF (bv. I1)" ""
ask ROOT_NAME     "root-persoon naam" ""

cat > "$ROOT/config/project.env" <<EOF
# Projectgegevens — automatisch geschreven door bin/init-project.sh.
WEBTREES_TREE=$WEBTREES_TREE
WEBTREES_URL=$WEBTREES_URL
ROOT_XREF=$ROOT_XREF
ROOT_NAME=$ROOT_NAME
EOF
ok "geschreven: config/project.env"

STB_TREE="$WEBTREES_TREE" STB_URL="$WEBTREES_URL" STB_XREF="$ROOT_XREF" STB_NAME="$ROOT_NAME" \
node -e '
const fs = require("fs");
const map = {
  "{{TREE}}": process.env.STB_TREE,
  "{{WEBTREES_URL}}": process.env.STB_URL,
  "{{ROOT_XREF}}": process.env.STB_XREF,
  "{{ROOT_NAME}}": process.env.STB_NAME,
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
