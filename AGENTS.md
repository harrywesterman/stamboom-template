# Stamboom-onderzoek — werkwijze

Dit project is **één genealogisch onderzoek**. De boom staat op **{{WEBTREES_URL}}**,
boom **`{{TREE}}`**, root-persoon **{{ROOT_NAME}} ({{ROOT_XREF}})**.

Dit bestand beschrijft **hoe je werkt**, niet wat er al gevonden is. Bevindingen horen in
`docs/onderzoek/`. Diepe per-bron details staan in `docs/werkwijze/`.

## 1. Wat je tot je beschikking hebt

| bron | MCP-tools | waarvoor |
|---|---|---|
| webtrees | `webtrees_mcp-server_*` | de boom zelf: personen, gezinnen, media, wijzigingen |
| Open Archieven | `openarchieven_*` | Nederlandse BS-akten (geboorte/huwelijk/overlijden) |
| Delpher | `newspapers_*` | kranten (KB) |
| FamilySearch | `familysearch_*` | volledige-tekstzoekopdracht, afbeeldingen, record search |
| OCR | `ocr_*` + `bin/ocr-handschrift.sh` | oude handschriften (17e–19e eeuw) |
| nl-gov | `nl-gov-mcp_*` | BAG, kadaster, CBS, wetgeving |
| Playwright | `playwright_browser_*` | laatste redmiddel voor webinterfaces |

Details: `docs/werkwijze/{webtrees-media,openarchieven,delpher,familysearch,ocr}.md`.

## 2. CRITICAL: de boom IS het werk van de gebruiker

De boom is **zeer compleet** en de gebruiker documenteert hem nauwgezet, inclusief
`NOTE`-blokken met bronlinks en mediascans. Het is een **ernstige fout** om bestaande
informatie — namen, data, plaatsen, beroepen, ouders, huwelijken, kinderen, kranten-
berichten, aktescans — als "nieuwe vondst" te presenteren. Dit is herhaaldelijk misgegaan.

### Verplichte werkwijze vóórdat je iets "nieuw" of "ontbrekend" noemt

1. **Lees het volledige record** van de persoon:
   `webtrees_mcp-server_get-record(tree='{{TREE}}', xref='I…', format='gedcom')`.
   Bekijk **alle** `NOTE`-blokken, alle `OCCU`, alle `OBJE` en de `FAMS`/`FAMC`-verwijzingen.
2. **Volg de familie-records** (`F###`): haal ze op en bekijk partner(s) en kinderen. Een
   huwelijk of gezin kan volledig in de boom staan zonder zichtbaar te zijn in het I-record.
3. **Check notities op bronlinks.** Staat de akte er al? Dan hoef je die niet opnieuw te
   "ontdekken".
4. **MCP-afwezigheid bewijst niets.** Controleer bij twijfel het I-**én** het F-record, en
   desnoods de browser-UI voordat je iets ontbrekend noemt.
5. **Rapporteer gescheiden:** wat staat al in webtrees, en wat is aantoonbaar nieuw. Noem
   alleen het laatste "nieuw". Vind je niets nieuws, zeg dat dan eerlijk.

Het doel van onderzoek is **data toevoegen die nog niet in de boom staat** — ontbrekende
personen, akten, bronnen, media — niet de bekende genealogie opnieuw afleiden.

## 3. Personen en relaties opzoeken

```
webtrees_mcp-server_search-general(tree='{{TREE}}', query='Westerman', search_individuals=true)
webtrees_mcp-server_get-record(tree='{{TREE}}', xref='I1')                  # samenvatting
webtrees_mcp-server_get-record(tree='{{TREE}}', xref='I1', format='gedcom')  # volledig
```

- `search-general` is een **index**, niet volledig: het is een indicatie, geen bewijs.
- Gebruik altijd `format='gedcom'` als je notes, media en familiekoppelingen wilt zien.
- Relaties in de `relationships`-array: `Couple` = partners, `ParentChild` = ouder→kind.
- `FAMC` = gezin waarin iemand kind is; `FAMS` = gezin waarin iemand partner is.

## 4. Media

**Regel: gebruik voor alles met afbeeldingen/media de webtrees-MCP**, niet de browser en
geen handgemaakte URL's. De MCP dekt vinden, lezen, uploaden, koppelen, ontkoppelen,
bijwerken en verwijderen.

1. **Vinden:** `OBJE`-regels in `get-record(..., format='gedcom')` → media-XREF (`X…`).
2. **Metadata:** `webtrees_mcp-server_get-media(tree, xref)` → `filename` (volledig
   relatief opslagpad, bv. `api-media/ab12…/naam.png`), `title`, `url`, `pending`, plus
   kortlevende signed `preview-url` (thumbnail) en `content-url` (origineel).
3. **Bytes op volledige resolutie:** `webtrees_mcp-server_download-media(...)` met de
   `filename` uit `get-media`. De bridge volgt de signed `content-url`, verifieert de
   SHA-256 en schrijft het bestand naar een tijdelijk pad; lees de teruggegeven
   `local-path` daarna met de `read`-tool. Geen base64, geen handmatige `curl`.
4. **Uploaden:** `upload-media` met `local-path` (nooit bytes verzinnen). De bridge regelt
   alle formaten t/m 20 MiB via een single-use signed URL; `upload-media-chunk` bestaat
   niet meer. Max. 20 MiB, JPEG/PNG/GIF/WebP/PDF.
5. **Koppelen:** `link-media` met `target-type` INDI/FAM/SOUR.
6. **Max. één media-write per record per pending-periode.** Een tweede poging geeft HTTP
   **409** ("Record has pending changes") tot een moderator de eerste heeft goedgekeurd.
   De 409 gaat vóór de groottevalidatie.

Volledige details en valkuilen: `docs/werkwijze/webtrees-media.md`.

## 5. Records wijzigen

`modify-record` **vervangt het hele GEDCOM-record**. Alles wat je niet meegeeft, verdwijnt.

- **Neem `FAMC` en álle `FAMS`-regels letterlijk over** uit
  `get-record(format='gedcom')`. De tool behoudt familiekoppelingen **niet** automatisch —
  dit is één keer echt misgegaan: na een `modify-record` verdween `1 FAMS @F26@` en leek
  het gezin van de persoon te zijn verdwenen, terwijl het F-record nog bestond.
- **Pending changes:** een wijziging komt in de goedkeuringswachtrij. `get-record` blijft de
  oude versie tonen. Vraag de gebruiker om goedkeuring en verifieer daarna.
- **Nooit twee keer dezelfde write op één record** — dat levert dubbele pending changes op
  die dubbel toegepast kunnen worden.
- Bij meerdere writes op één record: **eerst de media-changes** laten goedkeuren, daarna de
  record-edit.

## 6. Bronnen: wat wel en niet werkt

### Open Archieven (akten)
- **Beste tools:** `openarchieven_get_marriages(name1, name2)`, `get_births`, `get_deaths`.
  `search_records(name)` voor algemeen zoeken, `show_record(archive, identifier)` voor detail.
- **Matig:** `match_record(name, birthyear)` — matcht alleen bij exacte gegevens.
- **Slecht:** `search_transcriptions` (full-text op handschriftherkenning) — vooral ruis.
- Formaten: IIIF-image `https://images.memorix.nl/gra/iiif/{IMAGEID}/full/full/0/default.jpg`;
  A2A-identifier `{archive}:{uuid}`, bv. `gra:8d4a775c-…`.
- **Niet alles is gedigitaliseerd** — veel overlijdensakten (vooral na 1877) ontbreken.

### Delpher (kranten)
- **Query-syntax is kritisch.** Gebruik **PROX** voor twee termen:
  `newspapers_search_newspapers(source='delpher', query='Westerman PROX Heiligerlee')`.
  Multi-woord zonder PROX → **0 resultaten**; alleen één woord of PROX werkt.
- Algemene familienamen zijn te ruisig; combineer met een plaatsnaam.
- OCR is **niet 100% betrouwbaar**, en kleine dorpsfiguren komen vaak helemaal niet in de
  krant. Geen hit betekent niet "bestaat niet".

### FamilySearch
- `search-records` geeft historische akten (met akte-link), `search-persons` zoekt de boom,
  `get-person`/`get-ancestors` werken alleen voor de eigen toegankelijke boom.
- **Rate limits: doe het rustig.** Na veel snelle verzoeken volgt `Error 15 – Access Denied`.
  Stop dan, wacht 15–30 min en hervat langzamer. Vererger het niet.
- De volledige-tekstzoekopdracht (AI-OCR) is wisselvallig: dezelfde query kan het ene moment
  1000+ hits geven en het volgende 0. Probeer varianten en herhaal na een pauze.

### OCR van handschriften
- `bin/ocr-handschrift.sh <scan.png> [output.txt]` (kraken + ARletta).
- **Nooit binariseren** — dat vernietigt lage-contrast scans (0 regels gedetecteerd).
- Werkt goed op 17e–19e-eeuws administratief/notarieel schrift. **Niet** getraind op
  Kurrent/Sütterlin (Duits); gebruik daarvoor een Kurrent-model.
- Resultaten zijn ruis: valideer kritieke data altijd tegen het origineel.

Diepere details: `docs/werkwijze/`.

## 7. Werkwijze bij een nieuw document

0. **Lees eerst** het volledige bestaande record + familie-records + notities (sectie 2).
1. **Check webtrees:** `get-record(xref, format='gedcom')` — noteer alle OBJE, OCCU, NOTE,
   FAMS/FAMC.
2. **Zoek in de bronnen:** Open Archieven (akten), Delpher (kranten), FamilySearch, nl-gov.
3. **Verifieer of de scan al in webtrees zit** (persoon **én** partner, en het F-record)
   vóórdat je downloadt.
4. **Documenteer:** leg vast in `docs/onderzoek/` en scheid expliciet "stond al in webtrees"
   van "nieuw".

## 8. Onderzoekslog

Dé plek voor bevindingen is `docs/onderzoek/`. **Niet** in dit bestand.

- Eén dossier per persoon of per onderzoeksvraag: `docs/onderzoek/<xref>-<naam>.md`.
- Gebruik `docs/onderzoek/_TEMPLATE.md` als opzet.
- Houd `docs/onderzoek/index.md` bij als register.
- Elk dossier bevat: status (al in boom / nieuw), bronnen met links, een aktetabel, de
  media-XREF's, en open vragen.

## 9. Lessen en valkuilen

- **Nooit** bestaande webtrees-data als "nieuw" presenteren (sectie 2).
- **Nooit** beweren dat iets ontbreekt op basis van MCP-output alleen — check het I- én het
  F-record.
- **Nooit** blind aktes downloaden — check eerst of de scan al in de boom zit.
- **Huwelijksakten hangen vaak aan het F-record**, niet aan de I-records.
- **`modify-record` laat FAMS/FAMC vallen** als je ze niet expliciet meegeeft.
- **Eén media-write per record per pending-periode** (409).
- **`curl -F "note=…"` kapt af bij de eerste `;`** — vermijd puntkomma's in form-velden, of
  zet de volledige tekst later via `update-media`.
- **Playwright is het laatste redmiddel**, niet de standaard: de MCP's dekken vrijwel alles.
