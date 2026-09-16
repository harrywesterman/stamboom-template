# stamboom-template

Basisrepo voor een nieuw genealogisch onderzoek. Je kloont hem als **GitHub template**
(niet als clone) zodat elk onderzoek met een verse historie begint, en draait één
setup-commando.

## Snelstart op een nieuwe machine

```bash
gh repo create mijn-onderzoek --template harrywesterman/stamboom-template --private
cd mijn-onderzoek
./setup.sh
```

`setup.sh` doet alles: MCP-tools installeren, secrets controleren, de configuratie voor
opencode/codex/Claude Code genereren, skills installeren en een healthcheck draaien.
Opnieuw draaien is veilig en werkt de tools bij.

## Wat het oplevert

- **MCP-servers** voor webtrees, Open Archieven, Delpher (kranten), FamilySearch,
  OCR van handschriften (kraken/ARletta), nl-gov, Playwright en Context7.
- **Werkwijze** in `AGENTS.md` — hoe je onderzoekt, welke bronnen wel/niet werken, en de
  kritieke regel dat de bestaande boom nooit als "nieuwe vondst" mag worden gepresenteerd.
- **Onderzoekslog** in `docs/onderzoek/`, één dossier per persoon.

## Structuur

| pad | inhoud |
|---|---|
| `AGENTS.md` | generieke werkwijze (per project ingevuld door `bin/init-project.sh`) |
| `config/mcp.servers.json` | enige bron van waarheid voor alle MCP-servers |
| `config/secrets.env.example` | placeholders; de echte secrets staan buiten de repo |
| `bin/` | `setup.sh`-helpers: installeren, renderen, doctor, secrets, init |
| `docs/werkwijze/` | diepe per-bron knowhow (Delpher, FamilySearch, OCR, …) |
| `docs/onderzoek/` | persoonsdossiers + register |
| `docs/plans/` | ontwerp- en implementatieplannen |

## Secrets

Eén token is genoeg. Zet die in `~/.config/stamboom/secrets.env` (chmod 600, **buiten**
de repo, geldt voor al je projecten):

```bash
./bin/secrets-edit.sh
```

FamilySearch werkt niet met een token maar met een sessie-cookie: log één keer per machine
in via de MCP-tool `familysearch_login-with-browser`.

## Onderhoud

```bash
./setup.sh --update     # tools bijwerken
./setup.sh --check      # alleen healthcheck
./bin/doctor.sh         # idem, direct
```

## Nieuw project binnen een bestaande kloon

```bash
./bin/init-project.sh   # vraagt boom, webtrees-URL en root-persoon
```
