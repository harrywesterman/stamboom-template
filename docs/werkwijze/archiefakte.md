# archiefakte-mcp (Gelders Archief + Open Archieven)

Lokale MCP-server voor het zoeken van Gelders Archief-akten en het **ontdekken en
downloaden van volledige registerscans**. De server draait via stdio; de client start
het proces. Zoeken loopt via de **Open Archieven 1.1 API**; de scans komen rechtstreeks
van het Gelders Archief (permalink, HTTP — de bewezen route start géén browser).

Server: `archiefakte` → tools heten `archiefakte_*` (in opencode) of `search_acts`, …
in de ruwe MCP.

## Tools

| tool | doel |
|---|---|
| `search_acts` | Zoeken op naam, plaats, jaar, record-type en gebeurtenisdatum |
| `get_record` | Genormaliseerd record met aktenummer, aktedatum en bronpermalink |
| `inspect_register` | **Alle** scans van een register ontdekken; bewijst volledigheid |
| `resolve_act_scan` | Conservatieve akte→scan-resolver (metadata; optioneel OCR) |
| `download_scan` | Eén expliciet gekozen scan downloaden (géén aktematch) |
| `download_act` | Een gebonden akte downloaden, of een expliciet gekozen volgnummer |

Belangrijkste parameters:

- `search_acts(name, place?, year?, record_type?, date?, limit?, start?)` —
  `record_type`: `birth`/`geboorte`, `death`/`overlijden`, `marriage`/`huwelijk`.
  `date` = **gebeurtenisdatum**; `limit` 1–100; `start` voor paginering; `next_start`
  wijst naar de volgende API-pagina.
- `inspect_register(url, start?, limit?)` — `start` is **één-gebaseerd**. Geeft pas
  `complete=true` als discovery het vastgestelde totaal en de volgorde valideert.
- `resolve_act_scan(record_id | source_url, act_number?, date?, name?, reader?, max_scans?)`
  — `date` = **aktedatum**. Gebruik precies één van `record_id`/`source_url`.
- `download_act(record_id, scan_sequence?, reader?, allow_probable?)` — zonder
  `scan_sequence` downloadt alleen een `FOUND`-koppeling.

## Typische flow

```
archiefakte_search_acts(name='Derk Jan van Brink', place='Terwolde', year=1921, record_type='birth')
archiefakte_get_record(record_id='gld:E4203501-2A36-4A3E-9190-403665F46E77')
archiefakte_inspect_register(url='https://permalink.geldersarchief.nl/E42035012A364A3E9190403665F46E77')
archiefakte_resolve_act_scan(record_id='gld:E4203501-2A36-4A3E-9190-403665F46E77')
archiefakte_download_act(record_id='gld:E4203501-2A36-4A3E-9190-403665F46E77')
```

Er wordt **nooit automatisch het eerste zoekresultaat gekozen**. Meerdere records
blijven apart; `number_found` is het aantal persoonstreffers van de API vóór lokale
ontdubbeling.

## Downloaden en provenance

- Downloads komen in `GA_DATA_DIR/downloads` (default
  `~/.local/share/stamboom-tools/archiefakte-mcp/data/downloads`). Bestandsnaam:
  `<register>_scan-<volgnummer>.<ext>`.
- De **sidecar** bevat bronpermalink, register, inventaris, scan-ID, oorspronkelijke
  download-URL, UTC-tijd, SHA-256, dimensies, discoverymethode en representatietype.
- `output_format='original'` bewaart de ontvangen bytes **zonder hercompressie**. De
  bewezen bron is de viewer-downloadrepresentatie; identiteit met het archiefmaster-
  bestand is niet aangetoond.
- **Let op:** de lokale provenance bevat de volledige publieke download-URL (met
  tokens). Publiceer sidecars niet zonder die URL te redigeren. De MCP zelf redigeert
  JSON-provenance; de sidecar op schijf niet.
- De afbeelding komt als MCP-**resource** (`geldersarchief://scans/<id>.jpg`), niet als
  base64 in de tool-JSON. Alleen de laatste 128 downloads per sessie blijven als
  resource beschikbaar; de bestanden op schijf blijven staan.

## Status en betrouwbaarheid

- `download_act` geeft alleen bij een `FOUND`-koppeling bestanden. Bij `AMBIGUOUS`,
  `NOT_FOUND` of een niet-toegestane `PROBABLE`: `files=[]` plus bewijs/diagnostiek.
  `allow_probable=true` staat een voorlopige download toe (status blijft `PROBABLE`).
- Een expliciet gekozen `scan_sequence` geeft status **`SELECTED`**: dat is **geen**
  bewezen akte→scan-match. Bewaar de gevraagde recordmetadata apart van de
  ongeverifieerde aktevelden.
- `resolve_act_scan` bevestigt niets automatisch. De standaardreader is `disabled`
  (alleen expliciete metadata, geen OCR). Optionele readers: `tesseract`, `kraken`,
  `hybrid`; die gebruiken alleen lokaal geïnstalleerde software en roepen geen
  AI-provider aan. Zonder reader blijft een onduidelijk resultaat `AMBIGUOUS`.

## Installatie en configuratie

De MCP staat in `config/mcp.servers.json` en wordt door `./setup.sh` geïnstalleerd:
`git clone` + `uv sync --frozen`. De server draait als
`uv --directory <TOOLS_DIR>/archiefakte-mcp run --frozen geldersarchief-mcp`.

Vereist: **uv** en Python 3.12+. `GA_USER_AGENT` (default de webtrees-URL) wordt
meegestuurd zoals Open Archieven bij publiek gebruik vraagt. `GA_DATA_DIR` is
overschrijfbaar via `~/.config/stamboom/secrets.env`.

Optioneel voor de resolver: `brew install tesseract tesseract-lang` (tesseract) of de
kraken-venv uit `setup.sh` (`GA_KRAKEN_EXECUTABLE`). Playwright-chromium is alleen nodig
voor vieweronderzoek/fallbacks, niet voor de bewezen HTTP-discovery.
