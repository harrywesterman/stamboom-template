# FamilySearch

## Tools

- `familysearch_get-current-user` — controleer of je bent ingelogd.
- `familysearch_search-persons` — zoekt in de Family **Tree**.
- `familysearch_search-records` — **historische akten**; geeft sinds 11-09-2026 ook de
  akte-link (`ark`) terug. Persona-ID's (bv. `QLR1-7C9F`) zijn record-persona's, geen
  boomp personen.
- `familysearch_get-person` / `get-ancestors` / `get-descendants` — werkt **alleen** voor de
  eigen, toegankelijke boom.
- `familysearch_login-with-browser` — opent een browser om in te loggen. **Gebruik nooit
  wachtwoorden uit de chat.** De sessie wordt bewaard in `~/.familysearch-mcp/config.json`.
- `familysearch_download-document`, `familysearch_list-film-images`, `familysearch_search-catalog`.

## CRITICAL: rate limits

- Na veel snelle verzoeken blokkeert FamilySearch met **`Error 15 – Access Denied`**
  ("blocked by our security service").
- **Doe het rustig:** max. enkele afbeeldingen/zoekopdrachten per minuut, met pauzes van
  30–60 s.
- Bij een blokkade: **stoppen**, 15–30 min wachten, daarna rustiger hervatten. Vererger het
  niet met doorrammen.
- De volledige-tekstzoekopdracht is LLM-gebaseerd en wisselvallig: dezelfde query kan het ene
  moment 1000+ hits geven en het volgende 0. Probeer varianten en herhaal na een pauze.

## Volledige-tekstzoekopdracht (AI-OCR) — vaak de krachtigste bron

Ontsluit **niet-geïndexeerde** rechterlijke-, grond- en voogdijregisters.

1. Cookie inladen uit `~/.familysearch-mcp/config.json` als `.familysearch.org`-cookies.
2. Chromium: `~/.cache/ms-playwright/chromium-*/chrome-linux64/chrome` met
   `--no-sandbox --disable-dev-shm-usage --disable-http2`.
3. Zoekveld: `textarea[name="nlQuery"]` op `https://www.familysearch.org/nl/search/full-text`.
4. Viewer-URL: `https://www.familysearch.org/ark:/61903/…?view=fullText&keywords=<term>`
   springt naar de vindplaats en toont de OCR-transcriptie.

Via de MCP: `familysearch_search-full-text` met `keywords`, optioneel `collectionId` en
`matchMode` (`any`/`all`/`exact`). Met `includeFullTranscript` krijg je de hele OCR-tekst —
gebruik dat met een lage `limit`.

Zonder `collectionId` is het te ruisig; met `matchMode='all'` werkt het redelijk.

## Zoekstrategie die werkt

1. `search-records` op voornaam + achternaam + plaats om boomprofielen te vinden.
2. **Volledige-tekstzoekopdracht** met de exacte naamvariant — let op oude spelling
   (17e-eeuws: `Jaques` = Jacob, patroniemen).
3. Open de gevonden `ark:`-link met `view=fullText&keywords=<term>` en lees de transcriptie
   (OCR is ruis, maar namen/data komen eruit).
4. Voor bewijs van een ouder-kindrelatie: **voogdijrekeningen/weeskamer** en **doopboeken**
   zijn het meest kansrijk.

## Handige collecties

- **Groningen Legal, 1410–1991** — rechtbanken, voogdij, belasting, onroerend goed.
- **Groningen Properties, 1597–1940** — landregisters/kadasters.
- **Military Service, 1578–1998** — militie/signalementen.
- **Groningen Biographies, 1350–2006** — genealogieën/parentelen.
- **Netherlands, Friesland, Church Records, 1543–1911** — DTB Friesland (dopen/trouwen).

Veel niet-geïndexeerde registers zijn alleen **beeld-voor-beeld** te doorlopen; full-text is
te ruisig voor automatische extractie.
