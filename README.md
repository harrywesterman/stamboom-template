# stamboom-template

Basisrepo voor een nieuw genealogisch onderzoek. Je maakt er via GitHub een
**template-kopie** van, zodat elk onderzoek met een verse historie begint, en draait
één setup-commando.

## Snelstart op een nieuwe machine

```bash
gh repo create mijn-onderzoek --template harrywesterman/stamboom-template --private --clone
cd mijn-onderzoek
./setup.sh
```

> **`--clone` is verplicht.** Zonder die vlag maakt `gh` alleen de remote repository aan
> en heb je lokaal geen map om in te werken. Ben je dat vergeten, dan haal je de repo alsnog
> op met `gh repo clone harrywesterman/mijn-onderzoek`.

`setup.sh` doet alles: MCP-tools installeren, secrets controleren, de configuratie voor
opencode/codex/Claude Code genereren en een healthcheck draaien.
Opnieuw draaien is veilig en werkt de tools bij.

Vereist: `git`, `node` (22+), `npx`, `python3` en `uv`. Optioneel: `pipx`,
ImageMagick (`magick`) en `gh`.

## Wat het oplevert

- **MCP-servers** voor webtrees, Open Archieven, Gelders Archief (archiefakte-mcp),
  Delpher (kranten), FamilySearch, OCR van handschriften (kraken/ARletta), nl-gov,
  Playwright en Context7.
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

Alleen de webtrees-bridge bijwerken:

```bash
./bin/install-tools.sh --update --only webtrees-API --skip-extra
```

De integratie is bijgewerkt voor [webtrees-API `119809d`](https://github.com/harrywesterman/webtrees-API/commit/119809d)
(8 oktober 2026). Herstart de MCP-client na het bijwerken om de nieuwe bridge en toolschemas
te laden. De PHP-module op de webtrees-server wordt hiermee niet geïnstalleerd; werk die
afzonderlijk bij voor de nieuwe serverfuncties. Zie de werkwijze voor
[records](docs/werkwijze/webtrees-records.md) en [media](docs/werkwijze/webtrees-media.md).

## Nieuw project binnen een bestaande kloon

```bash
./bin/init-project.sh   # vraagt boom, webtrees-URL en root-persoon
```
