# webtrees: media

Alles met afbeeldingen/media gaat via de **webtrees-MCP** — niet via de browser en niet via
handgemaakte URL's. De MCP geeft ook de **bytes** (volledige resolutie): de lokale bridge
volgt een kortlevende signed URL en schrijft het bestand naar een tijdelijk pad, zodat er
geen base64 door het model gaat.

## 1. Media-XREF vinden

```
webtrees_mcp-server_get-record(tree='{{TREE}}', xref='I1', format='gedcom')
```

Regels als `1 OBJE @X13016@` geven de media-XREF. De bestandsnaam staat in het mediarecord:

```
0 @X13016@ OBJE
1 FILE Huwelijk … 1781.png
```

**Let op:** huwelijksakten hangen vaak aan het **F-record** (gezin), niet aan de I-records.
Check dus altijd beide.

## 2. Metadata en bytes

1. `webtrees_mcp-server_get-media(tree, xref)` → `filename` (het **volledige relatieve
   opslagpad**, bv. `api-media/ab12…/naam.png`), `title`, `url`, `pending`, plus een
   kortlevende signed `preview-url` (begrensde JPEG-thumbnail) en `content-url` (origineel;
   HMAC-ondertekend, purpose-bound, **5 minuten** geldig).
2. Bytes op volledige resolutie via `webtrees_mcp-server_download-media(...)` met de
   `filename` uit `get-media`. De bridge volgt de signed `content-url`, verifieert de
   SHA-256 en schrijft het bestand naar een tijdelijk pad. Het antwoord bevat `local-path`,
   `bytes` en `sha256` — **geen base64**.
3. Lees het bestand via `local-path` met de `read`-tool. Het model kan oud handschrift,
   Kurrent/Sütterlin en historische kaarten lezen.

De mediapagina toont alleen een **thumbnail** (~400 px); `content-url`/download geeft
volledige resolutie (vaak 2000–4000+ px breed). Voor lange documenten: knip de afbeelding in
stukken met ImageMagick (`magick scan.png -crop WxH+X+Y +repage deel.jpg`) en bekijk de delen
apart.

**Compatibiliteits-fallback** (meestal niet nodig): authenticated REST
`GET {{WEBTREES_URL}}/api/media/download?tree={{TREE}}&xref=X…&filename=<url-encoded-pad>`,
of volg de signed `content-url` rechtstreeks.

## 3. Uploaden

- **Standaard:** `upload-media` met `local-path` (een absoluut pad binnen
  `WEBTREES_UPLOAD_ROOTS`). De bridge leest en hasht het bestand, vraagt
  `create-media-upload` om een **single-use signed URL** en `PUT` de onbewerkte bytes
  daarheen. Geen base64, geen chunks, geen `api_write`. Verzin **nooit** bytes.
- `create-media-upload` wordt door de bridge zelf gebruikt en is **niet** aan het model
  blootgesteld. `upload-media-chunk` bestaat niet meer; gebruik na een transportfout
  `upload-media-status` om een eigen upload te inspecteren **zonder** opnieuw te uploaden.
- Een gestagede upload is **gebonden aan de geauthenticeerde webtrees-gebruiker** die
  `create-media-upload` aanriep: de PUT-route logt die identiteit opnieuw in. Ontbreekt de
  gebruiker of is die onbekend, dan volgt **403** (`access_denied`) en wordt er niets
  opgeslagen.
- **Compatibiliteits-fallback** (meestal niet nodig): directe MCP-clients kunnen inline
  base64 (`content-base64`) t/m 512 KiB gebruiken; authenticated REST `POST /api/media`
  (multipart: `tree`, `target-xref`, `target-type`, `title`, `date`, `file`) blijft bestaan.
- Te grote inline base64 → nette **413**: `inline_upload_too_large`,
  `maxInlineBytes: 524288`, `multipartEndpoint: /api/media`, `requiredScope: api_write`.
- Toegestaan: JPEG, PNG, GIF, WebP en **PDF** (PDF wordt ongewijzigd opgeslagen zonder te
  decoderen). MIME-type moet bij de extensie passen; max. 20 MiB en 40 megapixels; veilige
  bestandsnaam (geen pad); geen SVG/TIFF of corrupte bestanden.

## 4. Koppelen, ontkoppelen, bijwerken, verwijderen

`link-media` (target-type `INDI`/`FAM`/`SOUR`), `unlink-media`, `update-media`,
`delete-media`.

## Valkuilen

- **Max. één media-write per record per pending-periode.** Een tweede poging geeft HTTP
  **409** ("Record has pending changes") tot een moderator de eerste heeft goedgekeurd.
  De 409 gaat vóór de groottevalidatie.
- **`curl -F "note=…"` kapt af bij de eerste `;`** (puntkomma wordt als parameter-scheiding
  gezien). Gebruik geen `;` in `-F note=...`, of zet de volledige tekst later via
  `update-media`.
- Een privacy-only read kan tijdelijk **404** geven tot goedkeuring; bewaar de upload-XREF
  en upload **niet** opnieuw.
