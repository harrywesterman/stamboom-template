# Implementatieplan: `stamboom-template`

**Datum:** 16-09-2026
**Ontwerp:** `docs/plans/2026-09-16-stamboom-template-design.md`

Elke taak is af te vinken met een concreet verificatiecommando. Fasen 0–4 bouwen de
template; fase 5 publiceert; fase 6 (migratie) staat apart.

---

## Fase 0 — Scaffolding

### T1. Repo-init en basisbestanden
- **Bestanden:** `.gitignore`, `README.md`
- `.gitignore`: `secrets.env`, `.env`, `*.log`, `.DS_Store`, `.playwright-mcp/`, `tmp/`,
  `node_modules/`, gegenereerde client-configs (`opencode.json`, `.mcp.json`,
  `.codex/config.toml`).
- **Verificatie:** `git status --short` toont geen secrets.

### T2. `config/secrets.env.example`
- Alleen placeholders: `TOKEN=`, `WEBTREES_URL=`, `WEBTREES_TREE=tree1`, `UPLOAD_ROOTS=`.
- **Verificatie:** bestand bevat geen echte waarde.

### T3. `config/mcp.servers.json` — enige bron van waarheid
- Schema per server: `type` (local/remote), `command` (array met `${TOOLS_DIR}`/
  `${HOME}`-placeholders), `environment`, `url`, `auth` (`{"type":"bearer","env":"TOKEN"}`),
  `timeout`, `enabled`, `install` (repo/ref/build-cmd voor `install-tools.sh`).
- Servers: webtrees-mcp-server, familysearch, newspapers, nl-gov-mcp, ocr, openarchieven,
  playwright, context7.
- `familysearch` -> `ref: improvement`.
- **Verificatie:** `node -e "JSON.parse(require('fs').readFileSync('config/mcp.servers.json'))"`.

### T4. `bin/render-config.mjs`
- Leest `config/mcp.servers.json` + omgevingsvariabelen; schrijft drie formaten:
  - `opencode.json` -> `{ "$schema", "mcp": { <name>: {type, command, environment, headers, enabled} } }`
  - `.mcp.json` -> `{ "mcpServers": { <name>: {command, args, env} | {type:"http", url} } }`
  - `.codex/config.toml` -> `[mcp_servers.<name>]` met `command`/`args`/`env_vars`/
    `bearer_token_env_var`; remote met `url` + `[mcp_servers.<name>.http_headers]`.
- Auth per client: opencode `Bearer {env:TOKEN}`; Claude `Bearer ${TOKEN}`;
  codex `bearer_token_env_var = "TOKEN"`.
- **Verificatie:** `node bin/render-config.mjs --check` -> alle drie parseerbaar.

---

## Fase 1 — Installer

### T5. `bin/secrets-edit.sh`
- Maakt `~/.config/stamboom/secrets.env` aan (mode 600) uit `config/secrets.env.example`
  en opent het in `$EDITOR`.
- **Verificatie:** `stat -f %Lp` (macOS) / `stat -c %a` (Linux) = `600`.

### T6. `bin/install-tools.sh`
- Kloont/updatet in `$TOOLS_DIR` (default `~/.local/share/stamboom-tools`):
  webtrees-API, familysearch-mcp (`-b improvement`), newspapers-mcp, nl-gov-mcp.
- Bouwt: `npm ci && npm run build` waar van toepassing.
- Installeert: `pipx install mcp-ocr`; kraken-venv met **Python 3.13** (weigert 3.14 met
  duidelijke melding); ARletta-modellen naar `${OCR_MODELS:-$HOME/ocr-models}` via
  range-requests; `npx playwright install chromium`.
- Idempotent: bestaande clones -> `git pull --ff-only` (newspapers/nl-gov op gepinde
  commit blijven staan).
- **Verificatie:** bestanden bestaan; `node <tool>/build/index.js --help` draait.

### T7. `setup.sh`
- Orkestreert: prereq-check -> secrets-check -> `install-tools.sh` -> `render-config.mjs`
  -> superpowers clonen (`obra/superpowers`) + symlinks (`skills`, `plugins/superpowers.js`)
  -> `init-project.sh` (alleen als placeholders nog leeg zijn) -> `doctor.sh`.
- Vlaggen: `--check` (alleen doctor), `--update` (alleen tools), `--no-skills`.
- **Verificatie:** verse checkout -> `./setup.sh` eindigt met doctor-rapport.

---

## Fase 2 — Verificatie

### T8. `bin/doctor.sh`
- Per MCP een smoke-test: webtrees `get-version`, openarchieven, familysearch
  `get-current-user`, newspapers zoektest, OCR-test op sample.
- Uitvoer: groen/geel/rood per server; familysearch-rate-limit = geel (waarschuwing).
- Exitcode 0 als geen rood.
- **Verificatie:** `./bin/doctor.sh` op deze Mac -> alles groen/geel.

---

## Fase 3 — Kennis

### T9. `AGENTS.md` (template)
- Secties 1–9 zoals in het ontwerp; placeholders `{{TREE}}`, `{{WEBTREES_URL}}`,
  `{{ROOT_XREF}}`.
- Géén persoonsgeschiedenis, géén media-XREF-tabel.
- **Verificatie:** `wc -l AGENTS.md` < 300.

### T10. `docs/werkwijze/*.md`
- `webtrees-media.md`, `openarchieven.md`, `delpher.md`, `familysearch.md`, `ocr.md`,
  `nl-gov.md` — de diepe per-bron details die nu in de 1148-regelige AGENTS.md zitten.
- **Verificatie:** elke bron uit `config/mcp.servers.json` heeft een doc.

### T11. `docs/onderzoek/_TEMPLATE.md` + `index.md`
- Dossiersjabloon: status (al in boom / nieuw), bronnen, aktes-tabel, media-XREF's,
  open vragen; en een register.

---

## Fase 4 — Project-init

### T12. `bin/init-project.sh`
- Vraagt boom, webtrees-URL, root-persoon-XREF; schrijft die in `AGENTS.md` en
  `config/project.env`; maakt `docs/onderzoek/index.md` leeg aan.
- **Verificatie:** placeholders verdwenen uit `AGENTS.md`.

---

## Fase 5 — Publiceren en testen

### T13. Publiceren
- `gh repo create harrywesterman/stamboom-template --private --source=. --push`
- Repo instelling **"Template repository"** aanzetten.
- **Verificatie:** `gh repo create test-$(date +%s) --template harrywesterman/stamboom-template --clone`
  -> verse repo met één commit; `./setup.sh --check` groen.

---

## Fase 6 — Migratie bestaand project (apart goedkeuren)

### T14. `~/code/stamboom` herstructureren
- AGENTS.md splitsen: regels 1–273 + 623–712 -> `AGENTS.md`; rest -> `docs/onderzoek/`.
- Media naar Git LFS; `git lfs migrate import --include="*.png,*.jpg"`.
- **Verificatie:** AGENTS.md < 300 regels; `git lfs ls-files` toont de media.

---

## Risico's en aandachtspunten

| risico | maatregel |
|---|---|
| Python 3.14 breekt kraken | T6 weigert 3.14 expliciet, verwijst naar 3.13 |
| FamilySearch rate limit (`Error 15`) | doctor: geel, geen rood; nooit doorrammen |
| Playwright chromium groot | hervatbare install, sla over als aanwezig |
| Upstream `newspapers`/`nl-gov` wijzigen | pinnen op commit-hash in `mcp.servers.json` |
| Secrets per ongeluk in git | `.gitignore` + `git status`-check in T1 |
