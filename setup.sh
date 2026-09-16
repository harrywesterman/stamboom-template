#!/usr/bin/env bash
# Zet alles klaar om in dit project met de stamboom-MCP's te werken.
#
#   ./setup.sh                # volledige installatie (idempotent)
#   ./setup.sh --update       # tools bijwerken + herbouwen
#   ./setup.sh --check        # alleen healthcheck
#   ./setup.sh --skip-extra   # alleen de git-tools (geen OCR/kraken/playwright)
#
# Herhaald draaien is veilig: wat bestaat blijft staan, wat ontbreekt wordt gemaakt.

set -euo pipefail
# shellcheck source=bin/_common.sh
. "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/bin/_common.sh"

MODE="setup"
SKIP_EXTRA=0
for arg in "$@"; do
    case "$arg" in
        --check)      MODE="check" ;;
        --update)     MODE="update" ;;
        --skip-extra) SKIP_EXTRA=1 ;;
        -h|--help)    sed -n '2,11p' "$0"; exit 0 ;;
        *)            die "onbekende optie: $arg" ;;
    esac
done

# --- 1. prereqs -------------------------------------------------------------

check_prereqs() {
    log "prerequisites"
    local missing=0
    for cmd in git node npx python3; do
        if command -v "$cmd" >/dev/null 2>&1; then
            ok "$cmd"
        else
            err "$cmd ontbreekt"
            missing=1
        fi
    done
    for cmd in pipx uv magick gh; do
        if command -v "$cmd" >/dev/null 2>&1; then
            ok "$cmd (optioneel)"
        else
            warn "$cmd ontbreekt (optioneel)"
        fi
    done
    [ "$missing" = "0" ] || die "installeer de ontbrekende verplichte tools en probeer opnieuw"
}

# --- 2. secrets -------------------------------------------------------------

check_secrets() {
    log "secrets"
    if [ ! -f "$SECRETS" ]; then
        warn "geen $SECRETS"
        if [ "$MODE" != "check" ] && [ -t 0 ]; then
            "$ROOT/bin/secrets-edit.sh" || true
        else
            printf '      maak aan met: ./bin/secrets-edit.sh\n'
        fi
    elif [ -n "${TOKEN:-}" ]; then
        ok "$SECRETS (TOKEN gevonden)"
    else
        err "TOKEN is leeg in $SECRETS"
    fi
    ok "webtrees-URL: ${WEBTREES_URL:-https://www.stamboomwesterman.net}"
}

# --- 3. configuratie --------------------------------------------------------

render_config() {
    log "configuratie genereren"
    node "$ROOT/bin/render-config.mjs"
}

# --- 4. projectgegevens -----------------------------------------------------

maybe_init_project() {
    if grep -q '{{TREE}}' "$ROOT/AGENTS.md" 2>/dev/null; then
        log "projectgegevens"
        if [ -t 0 ]; then
            "$ROOT/bin/init-project.sh" || warn "init-project overgeslagen"
        else
            warn "AGENTS.md bevat nog placeholders; draai ./bin/init-project.sh"
        fi
    fi
}

# --- uitvoeren --------------------------------------------------------------

printf '%sstamboom-template setup%s\n' "$C_BOLD" "$C_RESET"
printf 'project:  %s\n' "$ROOT"
printf 'tools:    %s\n' "$TOOLS_DIR"
printf 'secrets:  %s\n' "$SECRETS"

if [ "$MODE" = "check" ]; then
    check_secrets
    log "healthcheck"
    exec "$ROOT/bin/doctor.sh"
fi

check_prereqs
check_secrets

if [ "$MODE" = "update" ]; then
    "$ROOT/bin/install-tools.sh" --update $([ "$SKIP_EXTRA" = "1" ] && echo --skip-extra)
else
    if [ "$SKIP_EXTRA" = "1" ]; then
        "$ROOT/bin/install-tools.sh" --skip-extra
    else
        "$ROOT/bin/install-tools.sh"
    fi
fi

render_config
maybe_init_project

log "healthcheck"
"$ROOT/bin/doctor.sh" || true

log "klaar"
printf 'Volgende stappen:\n'
printf '  1. log één keer in bij FamilySearch via de MCP-tool familysearch_login-with-browser\n'
printf '  2. open dit project in opencode en begin met onderzoeken\n'
