#!/usr/bin/env bash
# Installeert/updatet alle MCP-tools uit config/mcp.servers.json in TOOLS_DIR.
#
#   ./bin/install-tools.sh            # installeren wat ontbreekt
#   ./bin/install-tools.sh --update   # bestaande tools bijwerken + herbouwen
#   ./bin/install-tools.sh --skip-extra   # alleen de git-tools

set -euo pipefail
# shellcheck source=bin/_common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/_common.sh"

MODE="install"
SKIP_EXTRA=0
ONLY=""
while [ $# -gt 0 ]; do
    case "$1" in
        --update)     MODE="update" ;;
        --skip-extra) SKIP_EXTRA=1 ;;
        --only)       ONLY="${2:-}"; shift ;;
        -h|--help)    sed -n '2,7p' "$0"; exit 0 ;;
        *)            die "onbekende optie: $1" ;;
    esac
    shift
done

need git
need node
need uv
mkdir -p "$TOOLS_DIR"
log "tools-map: $TOOLS_DIR (modus: $MODE)"

# --- MCP-repo's -------------------------------------------------------------

while IFS=$'\t' read -r dir repo ref update build; do
    [ -n "$dir" ] || continue
    if [ -n "$ONLY" ] && [ "$dir" != "$ONLY" ]; then continue; fi
    dest="$TOOLS_DIR/$dir"

    if [ ! -d "$dest/.git" ]; then
        if [ "$MODE" = "update" ]; then
            skip "$dir (nog niet geïnstalleerd)"
            continue
        fi
        log "kloon $dir"
        git clone --quiet "$repo" "$dest" || die "kon $repo niet klonen"
        git -C "$dest" checkout --quiet "$ref" || die "kon $dir niet op $ref zetten"
        ok "$dir op $ref"
    elif [ "$MODE" = "update" ]; then
        if [ "$update" = "pull" ]; then
            log "update $dir"
            git -C "$dest" fetch --all --prune --quiet
            git -C "$dest" checkout --quiet "$ref"
            if git -C "$dest" pull --ff-only --quiet; then
                ok "$dir bijgewerkt ($ref)"
            else
                warn "$dir kon niet fast-forwarden; laat staan"
            fi
        else
            skip "$dir (gepind op een vaste commit)"
        fi
    fi

    if [ -n "$build" ]; then
        log "bouw $dir"
        if ( cd "$dest" && eval "$build" >/dev/null 2>&1 ); then
            ok "$dir gebouwd"
        else
            warn "$dir build mislukt — draai handmatig: cd $dest && $build"
        fi
    fi
done < <(cd "$ROOT" && node -e '
const c = require("./config/mcp.servers.json");
for (const t of Object.values(c.tools || {})) {
  console.log([t.dir, t.repo, t.ref, t.update || "pin", t.build || ""].join("\t"));
}')

if [ "$SKIP_EXTRA" = "1" ]; then
    log "extra installaties overgeslagen (--skip-extra)"
    exit 0
fi

# --- OCR --------------------------------------------------------------------

log "OCR-tool (mcp-ocr)"
if command -v mcp-ocr >/dev/null 2>&1; then
    if [ "$MODE" = "update" ] && command -v pipx >/dev/null 2>&1; then
        pipx upgrade mcp-ocr >/dev/null 2>&1 && ok "mcp-ocr bijgewerkt" || skip "mcp-ocr ongewijzigd"
    else
        skip "mcp-ocr aanwezig"
    fi
else
    if command -v pipx >/dev/null 2>&1; then
        pipx install mcp-ocr >/dev/null 2>&1 && ok "mcp-ocr geïnstalleerd" \
            || warn "pipx install mcp-ocr mislukt"
    else
        warn "pipx ontbreekt — installeer mcp-ocr handmatig"
    fi
fi

log "kraken (handschrift-OCR)"
if [ -x "$KRAKEN_VENV/bin/kraken" ]; then
    skip "kraken-venv aanwezig ($KRAKEN_VENV)"
else
    if command -v uv >/dev/null 2>&1; then
        mkdir -p "$(dirname "$KRAKEN_VENV")"
        uv venv --python 3.13 "$KRAKEN_VENV" >/dev/null 2>&1 \
            || die "kon geen Python 3.13-venv maken (kraken werkt niet op 3.14)"
        uv pip install --python "$KRAKEN_VENV/bin/python" kraken >/dev/null 2>&1 \
            && ok "kraken geïnstalleerd in $KRAKEN_VENV" \
            || warn "kraken installeren mislukt"
    else
        warn "uv ontbreekt — kraken niet geïnstalleerd"
    fi
fi

log "ARletta-modellen"
if python3 "$ROOT/bin/download-arletta-models.py" "$OCR_MODELS/ARletta/models"; then
    ok "modellen in $OCR_MODELS/ARletta/models"
else
    warn "modellen ophalen mislukt (kraken-OCR werkt pas daarna)"
fi

# --- Playwright -------------------------------------------------------------

log "Playwright chromium"
if [ "$MODE" = "update" ] || ! ls "$HOME/Library/Caches/ms-playwright" "$HOME/.cache/ms-playwright" 2>/dev/null | grep -q chromium; then
    npx --yes playwright install chromium >/dev/null 2>&1 \
        && ok "chromium aanwezig" || warn "playwright chromium installeren mislukt"
else
    skip "chromium aanwezig"
fi

log "klaar"
