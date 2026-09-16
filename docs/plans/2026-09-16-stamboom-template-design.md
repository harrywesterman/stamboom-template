# Ontwerp: `stamboom-template` — basisrepo voor nieuw stamboomonderzoek

**Datum:** 16-09-2026
**Status:** goedgekeurd

## Doel

Eén GitHub **template repository** waaruit elk nieuw genealogisch onderzoek vertrekt, met
alle MCP-servers, skills, agent-config en werkwijze vooraf ingesteld. Een nieuw project
start met een **verse historie** (template, niet clonen) en werkt op **elke machine**
(macOS/Linux/WSL) met één setup-commando.

## Succescriterium

Op een nieuwe machine:

```
gh repo create mijn-onderzoek --template harrywesterman/stamboom-template --private --clone
cd mijn-onderzoek
./setup.sh          # installeert tools, secrets-check, rendert configs, healthcheck
```

`--clone` is verplicht: zonder die vlag bestaat alleen de remote en is er lokaal geen map.

Daarna werkt opencode (en codex/Claude Code) direct met alle MCP's, zonder handmatig
configureren. `./setup.sh` is idempotent: opnieuw draaien = tools updaten.

## Architectuur — drie lagen

1. **`stamboom-template`** (GitHub, bron van waarheid) — config, `setup.sh`, `AGENTS.md`,
   `docs/werkwijze/`, skills-hook.
2. **`~/.local/share/stamboom-tools/`** (machine-breed, gedeeld over alle projecten) —
   de MCP-repo's, gekloond en gebouwd door `setup.sh`.
3. **`<project>/`** (de template-kloon) — `AGENTS.md`, `docs/onderzoek/*`, scans, notities.

Laag 2 staat bewust buiten het project zodat nieuwe projecten dezelfde tools hergebruiken.

## Repo-layout

```
stamboom-template/
├── AGENTS.md                     # generieke werkwijze + {{placeholders}}
├── README.md                     # quickstart
├── setup.sh                      # one-command installer, idempotent
├── bin/
│   ├── init-project.sh           # vraagt boom/URL/root-persoon -> vult placeholders
│   ├── update-tools.sh           # MCP-repo's pullen + herbouwen
│   ├── doctor.sh                 # healthcheck per MCP
│   ├── render-config.mjs         # mcp.servers.json -> 3 client-formaten
│   └── secrets-edit.sh           # opent secrets.env (chmod 600)
├── config/
│   ├── mcp.servers.json          # ENIGE bron van waarheid voor alle MCP's
│   └── secrets.env.example       # alleen placeholders
├── docs/
│   ├── werkwijze/                # delpher.md, openarchieven.md, familysearch.md, ocr.md, webtrees-media.md
│   └── onderzoek/                # per project gevuld
│       ├── _TEMPLATE.md          # persoonsdossier-sjabloon
│       └── index.md              # register
├── .gitignore
└── opencode.json / .mcp.json / .codex/config.toml   # GEGENEREERD, gitignored
```

**Rendering i.p.v. committen:** de drie client-configs bevatten absolute machinepaden en
verschillen dus per machine. `config/mcp.servers.json` is de enige bron van waarheid met
relatieve paden en `{env:...}`-referenties; `bin/render-config.mjs` genereert daaruit
`opencode.json`, `.mcp.json` en `.codex/config.toml`. Dit voorkomt drift tussen clients.

## MCP-servers in de template

| server | bron | installatie |
|---|---|---|
| `webtrees-mcp-server` | `harrywesterman/webtrees-API` (fork van Jefferson49/webtrees-API) | clone + `npm ci` |
| `familysearch` | `harrywesterman/familysearch-mcp`, **branch `improvement`** | clone -b + `npm ci && npm run build` |
| `newspapers` (Delpher) | `raphink/newspapers-mcp` (upstream) | clone + build |
| `nl-gov-mcp` | `WAINUTAI/NL-GOV-MCP` (upstream) | clone + build |
| `ocr` | pipx `mcp-ocr` | + kraken-venv (**Python 3.13**, niet 3.14) + ARletta-modellen (~21 MB) |
| `openarchieven` | remote `https://mcp.openarchieven.nl/` | geen |
| `playwright` | npx | chromium installeren |
| `context7` | npx | geen |

**Buiten scope:** `homeassistant` en `brewfather` (geen genealogie).

## Secrets

Eén env-secret in de praktijk:

| geheim | aard | aanpak |
|---|---|---|
| webtrees `TOKEN` | Bearer, langlevend | `~/.config/stamboom/secrets.env` (chmod 600, buiten de repo) -> `{env:TOKEN}` in alle configs |
| FamilySearch | sessie-cookie | geen env-secret; `familysearch_login-with-browser` één keer per machine (`~/.familysearch-mcp/config.json`, 600) |

- Repo bevat alleen `config/secrets.env.example` met placeholders.
- `setup.sh` sourcet het bestand buiten de repo; dat bestand overleeft alle projecten en
  komt nooit in git.
- Upgrade-pad (later, optioneel): 1Password `op inject` of SOPS/age — raakt de rest niet.

## Skills

`setup.sh` installeert `obra/superpowers` (v4.3.0) in `~/.config/opencode/superpowers` en
maakt de twee symlinks die opencode nodig heeft: `skills` en `plugins/superpowers.js`.

## Nieuwe AGENTS.md — structuur

Doel: ±200 regels *hoe te werken*, i.p.v. 1148 regels mengeling van methode en geschiedenis.

```
# Stamboom-onderzoek — werkwijze
## 1. Project                     (per project ingevuld: {{TREE}}, {{WEBTREES_URL}}, {{ROOT_XREF}})
## 2. CRITICAL: de boom IS het werk van de gebruiker
## 3. Personen & relaties opzoeken (webtrees MCP)
## 4. Media (vinden/bekijken/uploaden/koppelen, 409-regel)
## 5. Records wijzigen (modify-record: FAMS/FAMC mee, pending changes, nooit 2x)
## 6. Bronnen: wat werkt (Open Archieven, Delpher/PROX, FamilySearch/rate limits, OCR, nl-gov)
## 7. Werkwijze: nieuw document zoeken (5-stappen checklist)
## 8. Onderzoekslog (verwijst naar docs/onderzoek/<xref>-<naam>.md)
## 9. Lessen & valkuilen
```

Niet in de template-AGENTS.md (projectspecifiek, gaat naar `docs/onderzoek/`): de
media-XREF-tabel, het genealogisch verband, en alle persoonssecties.

## Onderzoekslog

- Elk persoon/sectie -> `docs/onderzoek/<xref>-<naam>.md` volgens `_TEMPLATE.md`.
- `docs/onderzoek/index.md` is het register.
- `AGENTS.md` bevat geen onderzoeksgeschiedenis meer.

## Migratie van het bestaande `~/code/stamboom`

- **AGENTS.md splitsen** op bestaande sectiegrenzen: regels 1–273 + 623–712 (methodologie)
  -> template; regels 146–166 + 274–622 + 713–1148 (bevindingen) -> `docs/onderzoek/`
  per persoon, bronlinks intact.
- **Repo-omvang:** nu 318 MB op GitHub, `.git` 515 MB, 518 tracked files, met `*.png|jpg`
  in git. Media naar **Git LFS** (`docs/onderzoek/media/`).
- Migratie is een eenmalige opruimactie; de template is de toekomst.

## Besluiten

| # | besluit |
|---|---|
| 1 | Secrets via `~/.config/stamboom/secrets.env` (600, buiten repo) + `.env.example` in repo |
| 2 | Media via Git LFS |
| 3 | Template-repo **private** |
| 4 | AGENTS.md = methodologie; alle bevindingen naar `docs/onderzoek/` |
| 5 | Template voor **nieuwe** onderzoeken; het huidige project migreren we apart |

## Verificatie

- `bin/doctor.sh` smoke-test per MCP: `get-version`, `get_archives`, `get-current-user`,
  een zoektest, en een OCR-test op een sample.
- Test op een schone machine of in een verse container voordat de template "klaar" heet.

## Risico's

- **Kraken/python:** vereist Python 3.13; setup moet 3.14 weigeren met duidelijke melding.
- **FamilySearch rate limits:** browser-login en full-text zijn fragiel; doctor moet dat
  als waarschuwing tonen, niet als harde fout.
- **Playwright chromium** is een grote download; setup moet hervatbaar zijn.
- **Upstream forks:** `newspapers`/`nl-gov` hebben geen eigen fork; pinnen op een commit om
  onverwachte upstream-wijzigingen te voorkomen.
